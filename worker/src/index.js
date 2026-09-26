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
import { TryAgain, listTrades, restStore, statsUpdatedAt, writeStats } from './firestore.js';
import { deleteCommunity, isCommunityId, removeMember } from './community.js';
import { eraseAccount } from './erase.js';
import { sendPush } from './fcm.js';
import { dailyReminder, forgetOldAnnouncements, notify } from './notify.js';
import { referenceRates } from './rates.js';

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
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === '/health') return json({ ok: true });
    if (url.pathname === '/rates' && request.method === 'GET') return rates(ctx);
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
  },

  // Every morning (wrangler.toml): the day's points are in; and what was
  // announced days ago no longer needs remembering.
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(
      (async () => {
        const token = await serviceAccountToken(env);
        await dailyReminder((m) => sendPush(env.FIREBASE_PROJECT_ID, token, m));
        await forgetOldAnnouncements(restStore(env.FIREBASE_PROJECT_ID, token, { budget: 5 }));
      })().catch((e) => console.error('morning job failed:', e)),
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
    const last = await statsUpdatedAt(env.FIREBASE_PROJECT_ID, uid, token);
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
    await writeStats(env.FIREBASE_PROJECT_ID, uid, { ...stats, ranked }, token);

    return json({ ...stats, ranked });
  } catch (error) {
    if (error.message === 'no such user') return json({ error: 'no profile' }, 404);
    console.error('recompute failed for', uid, error);
    return json({ error: 'could not update scores' }, 500);
  }
}
