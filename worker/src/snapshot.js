// A day's numbers, kept: every morning (index.js, the daily run) the worker
// counts accounts, who used the app, posts, trades and reports, and keeps
// them under stats/{date}, so the admin panel can draw how the app grows.
// Counted by Firestore (aggregation), never by reading every document.

const DHAKA_OFFSET_MS = 6 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/** The Dhaka date [ms] falls on: "2026-10-04". */
export function dhakaDate(ms) {
  return new Date(ms + DHAKA_OFFSET_MS).toISOString().slice(0, 10);
}

export async function takeSnapshot(store, now = new Date()) {
  const ms = now.getTime();
  const since = (days) => new Date(ms - days * DAY_MS);
  const accounts = await store.aggregate({ collection: 'users', sum: 'tradeCount' });
  const active = async (days) =>
    (await store.aggregate({ collection: 'presence', field: 'lastActiveAt', op: '>=', value: since(days) })).count;
  const fields = {
    date: dhakaDate(ms),
    at: now,
    accounts: accounts.count,
    trades: accounts.sum,
    active1d: await active(1),
    active7d: await active(7),
    active30d: await active(30),
    posts1d: (await store.aggregate({ collection: 'posts', field: 'postedAt', op: '>=', value: since(1) })).count,
    reports1d: (await store.aggregate({ collection: 'reports', field: 'createdAt', op: '>=', value: since(1) })).count,
  };
  await store.commit([{ upsert: `stats/${fields.date}`, fields }]);
  return fields;
}
