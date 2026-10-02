// This week's board: the same discipline score, over this week's closed
// trades alone, so someone who started this week can top it.
//
// A week is an ISO week — Monday to Sunday — in Dhaka time, named like
// "2026-W40". The app names weeks the same way (app/lib/core/week.dart) and
// asks for the board of the week it is in, so last week's numbers simply
// stop being asked for.

import { VIOLATION_WEIGHTS, rMultiple } from './stats.js';

/** Closed trades needed in a week to be on that week's board. */
export const MIN_WEEK_TRADES = 3;

const DAY_MS = 24 * 60 * 60 * 1000;
const DHAKA_OFFSET_MS = 6 * 60 * 60 * 1000;

/** The ISO week [ms] falls in, in Dhaka: "2026-W40". */
export function weekId(ms) {
  // The Dhaka calendar day, as a UTC midnight to do arithmetic on.
  const day = new Date(Math.floor((ms + DHAKA_OFFSET_MS) / DAY_MS) * DAY_MS);
  const weekday = day.getUTCDay() || 7; // Monday 1 … Sunday 7
  // The Thursday of this week decides which year the week belongs to.
  const thursday = new Date(day.getTime() + (4 - weekday) * DAY_MS);
  const year = thursday.getUTCFullYear();
  const jan1 = Date.UTC(year, 0, 1);
  const week = Math.floor((thursday.getTime() - jan1) / DAY_MS / 7) + 1;
  return `${year}-W${String(week).padStart(2, '0')}`;
}

/** The numbers of week [week] from [trades]. */
function statsFor(trades, week) {
  const closed = trades.filter(
    (t) => t.closedAt != null && weekId(Date.parse(t.closedAt)) === week,
  );
  let score = 0;
  let r = 0;
  for (const t of closed) {
    const penalty = [...new Set(t.violations ?? [])]
      .filter((v) => v in VIOLATION_WEIGHTS)
      .reduce((sum, v) => sum + VIOLATION_WEIGHTS[v], 0);
    score += Math.max(0, 100 - penalty);
    r += rMultiple(t) ?? 0;
  }
  return {
    board: closed.length >= MIN_WEEK_TRADES ? week : '',
    score: closed.length ? score / closed.length : 100,
    trades: closed.length,
    r,
  };
}

/**
 * This week's numbers from [trades]. weekBoard is the week's id when there
 * are enough trades to be ranked, '' otherwise — the one field the board
 * is asked for by.
 *
 * Last week's too, final once the week is over, so a challenge between two
 * traders can still be settled after it — whoever traded since or not.
 */
export function weeklyStats(trades, now = new Date()) {
  const nowMs = now instanceof Date ? now.getTime() : Date.parse(now);
  const week = statsFor(trades, weekId(nowMs));
  const last = statsFor(trades, weekId(nowMs - 7 * DAY_MS));
  return {
    weekBoard: week.board,
    weekScore: week.score,
    weekTrades: week.trades,
    weekR: week.r,
    lastWeekBoard: last.board,
    lastWeekScore: last.score,
    lastWeekTrades: last.trades,
  };
}
