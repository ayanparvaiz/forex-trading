// Writes each trader's leaderboard numbers, so the app never has to.
//
// The client cannot write disciplineScore, badgePoints and the rest — the
// Firestore rules refuse it, because a leaderboard ranked on numbers people
// type in themselves ranks whoever edits a number best. Something with more
// authority has to write them. Firebase would host that as a Cloud Function,
// but deploying one requires a billing account; this does the same job on
// Cloudflare's free tier with a service account.
//
// The flow is one request:
//   the app closes a trade and calls POST /recompute with its ID token
//   → the token is verified, which yields the uid
//   → that uid's trades are read from Firestore
//   → the six numbers are computed (stats.js, pinned to the app's formula)
//   → they are written to users/{uid}, and nothing else is
//
// A caller can only ever recompute their own row, and only from their own
// trades. There is no parameter that says whose numbers to change.
//
// POST /delete-account erases the caller's account from Firestore (erase.js).
// Same rule: the uid comes from the token, never from the request.
//
// GET /rates gives the day's reference rates the practice market starts
// from (rates.js). Public data, so no token, and cached at the edge.
//
// POST /notify announces something the caller just did — a message, a
// connection request, a post — to the phones of the people it concerns,
// once it has checked that it happened (notify.js). And every morning a
// cron trigger reminds everyone that the day's points are in.
//
// POST /community is a community's admin removing someone from it, or
// deleting it (community.js) — the two things that change other people's
// profiles. Only the admin the community names can do either.

import { MIN_RANKED_TRADES, leaderboardStats } from './stats.js';
import { serviceAccountToken, signedInRecently, verifyIdTokenClaims } from './google.js';
import { TryAgain, listTrades, restStore, scoreState, writeStats } from './firestore.js';
import { earnedAchievements, keepAchievements } from './achievements.js';
import { weeklyStats } from './weekly.js';
import { lastJournalDay, streakReminders } from './streak.js';
import { crownChampion } from './champion.js';
import { deleteCommunity, isCommunityId, removeMember } from './community.js';
import { eraseAccount } from './erase.js';
import { sendPush } from './fcm.js';
import { dailyReminder, eventReminders, forgetOldAnnouncements, notify } from './notify.js';
import { referenceRates } from './rates.js';
import { AdminError, adminAction, identityToolkit, liftExpiredBans } from './admin.js';
import { autoHideReported, reportAlerts, sendScheduled } from './admin-cron.js';
import { takeSnapshot } from './snapshot.js';
import { HelpError, passwordHelp } from './help.js';

// The quarter-hourly trigger in wrangler.toml, for event reminders. The
// other, daily, is the morning one.
const EVENT_CRON = '*/15 * * * *';

// 8 pm in Dhaka: streaks that end at midnight.
const STREAK_CRON = '0 14 * * *';

// Between the event reminders, so each run keeps the free plan's requests to
// itself: the admins' work (admin-cron.js) — bans whose days are up lifted,
// announcements scheduled for now sent, new reports told to the admins'
// phones, and a post enough people reported hidden until someone looks.
const ADMIN_CRON = '5,20,35,50 * * * *';

// How often one account may trigger a recompute.
//
// A recompute reads every trade the account has, and Firestore's free tier is
// 50,000 reads a day for the whole project. Without a floor, one account in a
// loop could spend the day's quota for everyone. Closing trades faster than
// this loses nothing: the next recompute includes them.
const MIN_INTERVAL_MS = 15_000;

// Deleting an account needs the password typed within this many seconds.
// The app asks for it on the delete screen and signs in again with it just
// before calling, so an unlocked phone left on a table is not enough.
const FRESH_SIGN_IN_S = 5 * 60;

// Firestore calls per /delete-account request, out of the 50 outgoing
// requests the free plan allows — the rest are for keys and tokens. An
// account with more than this can take is finished over several requests.
const ERASE_BUDGET = 40;

// Firestore calls per /notify request. With the pushes themselves (at most
// MAX_PUSHES in notify.js) and the token checks, inside the free plan's 50.
const NOTIFY_BUDGET = 18;

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });

// Where the admin panel is served from; its browser calls /admin from there.
const ADMIN_ORIGINS = new Set([
  'https://forex-social-admin.web.app',
  'https://forex-social-admin.firebaseapp.com',
  'http://localhost:3000',
]);

/** [response], readable by the admin panel when it is the one asking. */
function withCors(request, response) {
  const origin = request.headers.get('origin');
  if (!ADMIN_ORIGINS.has(origin)) return response;
  const headers = new Headers(response.headers);
  headers.set('access-control-allow-origin', origin);
  headers.set('access-control-allow-methods', 'POST, OPTIONS');
  headers.set('access-control-allow-headers', 'authorization, content-type');
  headers.set('access-control-max-age', '86400');
  headers.set('vary', 'origin');
  return new Response(response.body, { status: response.status, headers });
}

function bearer(request) {
  const header = request.headers.get('authorization') ?? '';
  return header.startsWith('Bearer ') ? header.slice(7).trim() : null;
}

// How long one fetch of the reference rates is served. They change once a
// working day; an hour keeps the source unbothered and the app current.
const RATES_CACHE_S = 3600;

/** The day's reference rates, from the edge cache when it has them. */
async function rates(ctx) {
  const cache = caches.default;
  const key = new Request('https://rates.invalid/v1');
  const hit = await cache.match(key);
  if (hit) return hit;
  try {
    const response = new Response(JSON.stringify(await referenceRates()), {
      headers: {
        'content-type': 'application/json',
        'cache-control': `public, max-age=${RATES_CACHE_S}`,
      },
    });
    ctx.waitUntil(cache.put(key, response.clone()));
    return response;
  } catch (error) {
    console.error('rates failed:', error);
    return json({ error: 'rates unavailable' }, 502);
  }
}

const routes = {
  '/recompute': (claims, env) => recompute(claims.sub, env),
  '/delete-account': deleteAccount,
  '/notify': notifyRoute,
  '/community': communityRoute,
  '/admin': adminRoute,
};

/** Every route but the admin panel's preflight. */
async function serve(request, env, ctx) {
  const url = new URL(request.url);

  if (url.pathname === '/health') return json({ ok: true });
  if (url.pathname === '/rates' && request.method === 'GET') return rates(ctx);
  // For someone who cannot sign in, so before the token check.
  if (url.pathname === '/help' && request.method === 'POST') return helpRoute(env, request);
  const route = routes[url.pathname];
  if (!route) return json({ error: 'not found' }, 404);
  if (request.method !== 'POST') return json({ error: 'method not allowed' }, 405);

  const idToken = bearer(request);
  if (!idToken) return json({ error: 'sign in first' }, 401);

  let claims;
  try {
    claims = await verifyIdTokenClaims(idToken, env.FIREBASE_PROJECT_ID);
  } catch (error) {
    // Never echo why: telling a caller which check their forged token
    // failed is help they should not get.
    console.warn('rejected token:', error.message);
    return json({ error: 'sign in first' }, 401);
  }

  return route(claims, env, request);
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    // The admin panel's browser asks first, then reads the answer: both
    // need its origin allowed.
    if (url.pathname === '/admin') {
      if (request.method === 'OPTIONS') return withCors(request, new Response(null, { status: 204 }));
      return withCors(request, await serve(request, env, ctx));
    }
    return serve(request, env, ctx);
  },

  // Every morning (wrangler.toml): the day's points are in; and what was
  // announced days ago no longer needs remembering.
  async scheduled(event, env, ctx) {
    ctx.waitUntil(
      (async () => {
        const token = await serviceAccountToken(env);
        const push = (m) => sendPush(env.FIREBASE_PROJECT_ID, token, m);
        // Every quarter hour: events about to start remind those going.
        if (event.cron === EVENT_CRON) {
          await eventReminders(restStore(env.FIREBASE_PROJECT_ID, token, { budget: 15 }), push);
          return;
        }
        if (event.cron === ADMIN_CRON) {
          await adminRun(env, token, push);
          return;
        }
        if (event.cron === STREAK_CRON) {
          await streakReminders(restStore(env.FIREBASE_PROJECT_ID, token, { budget: 10 }), push);
          return;
        }
        await dailyReminder(push);
        await forgetOldAnnouncements(restStore(env.FIREBASE_PROJECT_ID, token, { budget: 5 }));
        // On the first mornings of a month: last month's champion.
        await crownChampion(restStore(env.FIREBASE_PROJECT_ID, token, { budget: 6 }));
        // The day's numbers, for the admin panel's growth chart.
        await takeSnapshot(restStore(env.FIREBASE_PROJECT_ID, token, { budget: 8 }));
      })().catch((e) => console.error(`scheduled job ${event.cron} failed:`, e)),
    );
  },
};

/** Announces what the caller says they just did, once it checks out. */
async function notifyRoute(claims, env, request) {
  let event;
  try {
    event = await request.json();
  } catch {
    return json({ error: 'bad request' }, 400);
  }
  try {
    const token = await serviceAccountToken(env);
    const store = restStore(env.FIREBASE_PROJECT_ID, token, { budget: NOTIFY_BUDGET });
    const push = (message) => sendPush(env.FIREBASE_PROJECT_ID, token, message);
    return json(await notify(store, push, claims.sub, event));
  } catch (error) {
    if (error instanceof TryAgain) return json({ sent: 0, skipped: 'busy' });
    console.error('notify failed for', claims.sub, error);
    return json({ error: 'could not notify' }, 500);
  }
}

/**
 * A community's admin removing someone ({action: 'remove', communityId,
 * uid}) or deleting it ({action: 'delete', communityId}).
 *
 * {done: false} means call again, as with deleting an account: a large
 * community takes more than one request to delete.
 */
async function communityRoute(claims, env, request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'bad request' }, 400);
  }
  const { action, communityId, uid } = body ?? {};
  const removing = action === 'remove';
  if (!isCommunityId(communityId) || (!removing && action !== 'delete')) {
    return json({ error: 'bad request' }, 400);
  }
  if (removing && (typeof uid !== 'string' || !/^[A-Za-z0-9]{1,128}$/.test(uid))) {
    return json({ error: 'bad request' }, 400);
  }
  try {
    const token = await serviceAccountToken(env);
    const store = restStore(env.FIREBASE_PROJECT_ID, token, { budget: ERASE_BUDGET });
    const community = await store.get(`communities/${communityId}`, ['createdBy']);
    // Already deleted: nothing left to do, and nothing to remove anyone from.
    if (!community) return json({ done: true });
    if (community.createdBy !== claims.sub) return json({ error: 'not your community' }, 403);
    if (removing) {
      if (uid === claims.sub) return json({ error: 'the admin is not removed, the community is deleted' }, 400);
      await removeMember(store, communityId, uid);
    } else {
      await deleteCommunity(store, communityId);
    }
    return json({ done: true });
  } catch (error) {
    if (error instanceof TryAgain) return json({ done: false });
    console.error('community change failed for', claims.sub, error);
    return json({ error: 'could not change the community' }, 500);
  }
}

/**
 * Erases the caller's account, or as much of it as one request can.
 *
 * {done: false} means call again: this request ran out of budget, or
 * something changed under it. Every call starts from the top and skips what
 * is already gone, so the app just repeats until {done: true} — and then
 * deletes the sign-in itself.
 */
async function deleteAccount(claims, env) {
  if (!signedInRecently(claims, FRESH_SIGN_IN_S)) {
    return json({ error: 'sign in again' }, 403);
  }
  try {
    const token = await serviceAccountToken(env);
    await eraseAccount(restStore(env.FIREBASE_PROJECT_ID, token, { budget: ERASE_BUDGET }), claims.sub);
    return json({ done: true });
  } catch (error) {
    if (error instanceof TryAgain) return json({ done: false });
    console.error('delete failed for', claims.sub, error);
    return json({ error: 'could not delete' }, 500);
  }
}

async function recompute(uid, env) {
  // First line of throttling, and it is free: a per-location cache entry,
  // checked before anything touches Firestore. Most repeat calls stop here.
  const cache = caches.default;
  const throttleKey = new Request(`https://throttle.invalid/${uid}`);
  if (await cache.match(throttleKey)) {
    return json({ error: 'too soon', retryAfterMs: MIN_INTERVAL_MS }, 429);
  }

  try {
    const token = await serviceAccountToken(env);

    // Second line, in Firestore itself, for calls that land on a different
    // Cloudflare location than the last one. Costs one read.
    const { updatedAt: last, achievements: before, lessonsDone } = await scoreState(
      env.FIREBASE_PROJECT_ID,
      uid,
      token,
    );
    if (last != null && Date.now() - last < MIN_INTERVAL_MS) {
      return json({ error: 'too soon', retryAfterMs: MIN_INTERVAL_MS }, 429);
    }

    await cache.put(
      throttleKey,
      new Response('1', {
        headers: { 'cache-control': `max-age=${Math.ceil(MIN_INTERVAL_MS / 1000)}` },
      }),
    );

    const trades = await listTrades(env.FIREBASE_PROJECT_ID, uid, token);
    const stats = leaderboardStats(trades);
    // Written here rather than left to the query, so the leaderboard can ask
    // "ranked == true" with an equality filter and one index.
    const ranked = stats.tradeCount >= MIN_RANKED_TRADES;
    // Earned now, added to what was earned before: nothing is taken away.
    const achievements = keepAchievements(
      before,
      earnedAchievements(trades, stats, lessonsDone),
    );
    // This week's board, from this week's trades alone.
    const week = weeklyStats(trades);
    // The day of the last lesson, for the evening streak reminder.
    const journalDay = lastJournalDay(trades);
    await writeStats(
      env.FIREBASE_PROJECT_ID,
      uid,
      { ...stats, ranked, achievements, ...week, journalDay },
      token,
    );

    return json({ ...stats, ranked, achievements, ...week, journalDay });
  } catch (error) {
    if (error.message === 'no such user') return json({ error: 'no profile' }, 404);
    console.error('recompute failed for', uid, error);
    return json({ error: 'could not update scores' }, 500);
  }
}

/** A locked-out person asking the admins for a new password (help.js). */
async function helpRoute(env, request) {
  const text = await request.text();
  if (text.length > 2000) return json({ error: 'bad request' }, 400);
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    return json({ error: 'bad request' }, 400);
  }
  try {
    const token = await serviceAccountToken(env);
    return json(await passwordHelp(restStore(env.FIREBASE_PROJECT_ID, token, { budget: 4 }), body));
  } catch (error) {
    if (error instanceof HelpError) return json({ error: 'bad request' }, 400);
    console.error('help request failed:', error);
    return json({ error: 'could not send that' }, 500);
  }
}

/**
 * The quarter-hourly work for the admins. Each job has its own budget and
 * its own failure: one that runs out or breaks leaves the others to finish,
 * and carries on next time. Together they stay inside the free plan's fifty
 * requests a run.
 */
async function adminRun(env, token, push) {
  const project = env.FIREBASE_PROJECT_ID;
  const auth = identityToolkit(project, token);
  const now = new Date();
  const jobs = {
    bans: () => liftExpiredBans(restStore(project, token, { budget: 3 }), auth, now),
    scheduled: () => {
      const store = restStore(project, token, { budget: 14 });
      // As the admin who scheduled it, so it is checked, kept and logged as
      // if they had pressed Send.
      const send = (by, body) => adminAction(store, {
        auth,
        push,
        journal: restStore(project, token, { budget: 2 }),
      }, by, body, now);
      return sendScheduled(store, send, now);
    },
    alerts: () => reportAlerts(restStore(project, token, { budget: 6 }), push, now),
    hidden: () => autoHideReported(restStore(project, token, { budget: 6 }), now),
  };
  for (const [name, job] of Object.entries(jobs)) {
    try {
      await job();
    } catch (error) {
      console.error(`admin job ${name} failed:`, error.message);
    }
  }
}

/**
 * The admin panel's requests (worker/src/admin.js). {done: false} means call
 * again, as with deleting an account.
 */
async function adminRoute(claims, env, request) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'bad request' }, 400);
  }
  try {
    const token = await serviceAccountToken(env);
    const store = restStore(env.FIREBASE_PROJECT_ID, token, { budget: ERASE_BUDGET });
    const result = await adminAction(store, {
      auth: identityToolkit(env.FIREBASE_PROJECT_ID, token),
      push: (m) => sendPush(env.FIREBASE_PROJECT_ID, token, m),
      // The activity log's two calls, kept apart from the job's own.
      journal: restStore(env.FIREBASE_PROJECT_ID, token, { budget: 2 }),
    }, claims.sub, body);
    return json(result);
  } catch (error) {
    if (error instanceof TryAgain) return json({ done: false });
    if (error instanceof AdminError) return json({ error: error.message }, error.status);
    console.error('admin action failed for', claims.sub, body?.action, error);
    return json({ error: 'could not do that' }, 500);
  }
}
