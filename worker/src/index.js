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

import { leaderboardStats } from './stats.js';
import { serviceAccountToken, verifyIdToken } from './google.js';
import { listTrades, statsUpdatedAt, writeStats } from './firestore.js';

// How often one account may trigger a recompute.
//
// A recompute reads every trade the account has, and Firestore's free tier is
// 50,000 reads a day for the whole project. Without a floor, one account in a
// loop could spend the day's quota for everyone. Closing trades faster than
// this loses nothing: the next recompute includes them.
const MIN_INTERVAL_MS = 15_000;

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });

function bearer(request) {
  const header = request.headers.get('authorization') ?? '';
  return header.startsWith('Bearer ') ? header.slice(7).trim() : null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === '/health') return json({ ok: true });
    if (url.pathname !== '/recompute') return json({ error: 'not found' }, 404);
    if (request.method !== 'POST') return json({ error: 'method not allowed' }, 405);

    const idToken = bearer(request);
    if (!idToken) return json({ error: 'sign in first' }, 401);

    let uid;
    try {
      uid = await verifyIdToken(idToken, env.FIREBASE_PROJECT_ID);
    } catch (error) {
      // Never echo why: telling a caller which check their forged token
      // failed is help they should not get.
      console.warn('rejected token:', error.message);
      return json({ error: 'sign in first' }, 401);
    }

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
      await writeStats(env.FIREBASE_PROJECT_ID, uid, stats, token);

      return json(stats);
    } catch (error) {
      if (error.message === 'no such user') return json({ error: 'no profile' }, 404);
      console.error('recompute failed for', uid, error);
      return json({ error: 'could not update scores' }, 500);
    }
  },
};
