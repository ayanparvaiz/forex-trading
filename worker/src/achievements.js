// Milestones a trader keeps once reached — earned from their own closed
// trades, written by the worker beside their scores, never taken away. A
// streak that breaks still happened.
//
// The ids are stored on profiles; the app draws each by its id
// (app/lib/models/achievement.dart). Never rename one.

import { VIOLATION_WEIGHTS, rMultiple } from './stats.js';

/** Every achievement there is, in the order a profile shows them. */
export const ACHIEVEMENTS = [
  'first_trade',
  'ranked',
  'fifty_trades',
  'hundred_trades',
  'clean_ten',
  'big_winner',
  'streak_7',
  'streak_30',
  'iron_discipline',
];

const broke = (t) => (t.violations ?? []).some((v) => v in VIOLATION_WEIGHTS);

/** The longest run of closed trades in a row with no rule broken. */
function longestCleanRun(closed) {
  let best = 0;
  let run = 0;
  for (const t of closed) {
    run = broke(t) ? 0 : run + 1;
    best = Math.max(best, run);
  }
  return best;
}

/**
 * What [trades] earn now, given the [stats] worked out from them. Closed
 * trades only, in the order they closed.
 */
export function earnedAchievements(trades, stats) {
  const closed = trades
    .filter((t) => t.closedAt != null)
    .sort((a, b) => Date.parse(a.closedAt) - Date.parse(b.closedAt));
  const n = closed.length;
  const earned = new Set();
  if (n >= 1) earned.add('first_trade');
  if (n >= 5) earned.add('ranked');
  if (n >= 50) earned.add('fifty_trades');
  if (n >= 100) earned.add('hundred_trades');
  if (longestCleanRun(closed) >= 10) earned.add('clean_ten');
  if (closed.some((t) => (rMultiple(t) ?? 0) >= 3)) earned.add('big_winner');
  if (stats.journalStreak >= 7) earned.add('streak_7');
  if (stats.journalStreak >= 30) earned.add('streak_30');
  if (n >= 20 && stats.disciplineScore >= 90) earned.add('iron_discipline');
  return ACHIEVEMENTS.filter((a) => earned.has(a));
}

/**
 * [before] with whatever [now] adds, in the order of [ACHIEVEMENTS]. Never
 * fewer: an achievement once written stays. Ids this version does not know
 * are kept too, so an older worker never drops a newer one's.
 */
export function keepAchievements(before, now) {
  const all = new Set([...(before ?? []), ...now]);
  const known = ACHIEVEMENTS.filter((a) => all.has(a));
  const unknown = [...all].filter((a) => !ACHIEVEMENTS.includes(a));
  return [...known, ...unknown];
}
