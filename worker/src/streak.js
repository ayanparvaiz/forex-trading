// The evening nudge: someone whose journal streak ends at midnight unless
// they write today's lesson hears so at 8 pm in Dhaka.
//
// The day of the last journaled trade is written with the scores
// (journalDay); a streak still alive whose last day was yesterday is the
// one about to break.

import { pushMessage } from './fcm.js';

const DAY_MS = 24 * 60 * 60 * 1000;
const DHAKA_OFFSET_MS = 6 * 60 * 60 * 1000;

/** The Dhaka calendar day [ms] falls on: "2026-10-02". */
export function dhakaDay(ms) {
  return new Date(ms + DHAKA_OFFSET_MS).toISOString().slice(0, 10);
}

/** The Dhaka day of the latest closed trade with a lesson, or ''. */
export function lastJournalDay(trades) {
  let latest = null;
  for (const t of trades) {
    if (t.closedAt == null || (t.lesson ?? '').trim() === '') continue;
    const ms = Date.parse(t.closedAt);
    if (latest == null || ms > latest) latest = ms;
  }
  return latest == null ? '' : dhakaDay(latest);
}

const TEXT = {
  bn: {
    title: (n) => `🔥 ${n} দিনের স্ট্রিক`,
    body: 'আজকের লেসনটা লিখে ফেলুন — রাত ১২টায় স্ট্রিক ভেঙে যাবে।',
  },
  en: {
    title: (n) => `🔥 ${n}-day streak`,
    body: "Write today's lesson — the streak ends at midnight.",
  },
};

/** At most this many phones an evening: the free plan's request budget. */
export const MAX_STREAK_PUSHES = 25;

/**
 * Tells everyone whose streak ends tonight. [push] sends one message and
 * says 'sent' or 'gone'. Returns how many were sent.
 */
export async function streakReminders(store, push, now = Date.now()) {
  const yesterday = dhakaDay(now - DAY_MS);
  const due = await store.find({
    collection: 'users',
    field: 'journalDay',
    value: yesterday,
    limit: 100,
    fields: ['journalStreak'],
  });
  const streaks = new Map();
  for (const r of due) {
    const n = r.data.journalStreak;
    if (typeof n === 'number' && n > 0) streaks.set(r.path.split('/')[1], n);
  }
  if (!streaks.size) return 0;

  const devices = [];
  const uids = [...streaks.keys()];
  for (let i = 0; i < uids.length && devices.length < MAX_STREAK_PUSHES; i += 30) {
    const rows = await store.find({
      collection: 'devices',
      group: true,
      field: 'uid',
      op: 'in',
      value: uids.slice(i, i + 30),
      limit: 200,
      fields: ['uid', 'language'],
    });
    devices.push(...rows);
  }

  let sent = 0;
  const gone = [];
  for (const d of devices.slice(0, MAX_STREAK_PUSHES)) {
    const t = TEXT[d.data.language] ?? TEXT.bn;
    try {
      const result = await push(pushMessage({
        token: d.path.split('/').pop(),
        title: t.title(streaks.get(d.data.uid) ?? 1),
        body: t.body,
        data: { type: 'daily' },
      }));
      if (result === 'gone') gone.push({ delete: d.path });
      else sent++;
    } catch (error) {
      console.warn('streak push failed:', error.message);
    }
  }
  if (gone.length) await store.commit(gone).catch(() => {});
  return sent;
}
