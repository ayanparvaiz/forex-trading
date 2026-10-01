import { test } from 'node:test';
import assert from 'node:assert/strict';

import { earnedAchievements, keepAchievements } from '../src/achievements.js';
import { leaderboardStats } from '../src/stats.js';

/** A closed EUR/USD buy of 0.1 lots, risking 20 pips, that ends at [r] R. */
function trade(day, { r = 1, violations = [], lesson = 'kept the plan' } = {}) {
  const entry = 1.1;
  const stop = entry - 0.002;
  // Spread costs 0.8 pip of the 20 risked, so aim past it.
  const exit = entry + (r * 20 + 0.8) * 0.0001;
  const opened = new Date(Date.UTC(2026, 8, day, 4));
  return {
    symbol: 'EUR/USD',
    direction: 'buy',
    lots: 0.1,
    entryPrice: entry,
    stopPrice: stop,
    exitPrice: exit,
    openedAt: opened.toISOString(),
    closedAt: new Date(opened.getTime() + 3600_000).toISOString(),
    violations,
    lesson,
  };
}

const earned = (trades, now = new Date(Date.UTC(2026, 9, 1, 12))) =>
  earnedAchievements(trades, leaderboardStats(trades, now));

test('nothing for nothing', () => {
  assert.deepEqual(earned([]), []);
});

test('the first trade, then the board', () => {
  assert.deepEqual(earned([trade(1)]), ['first_trade']);
  const five = [1, 2, 3, 4, 5].map((d) => trade(d, { violations: ['movedStop'] }));
  assert.deepEqual(earned(five), ['first_trade', 'ranked']);
});

test('ten clean in a row — a broken rule starts the count again', () => {
  const nine = Array.from({ length: 9 }, (_, i) => trade(i + 1));
  const broken = trade(10, { violations: ['riskTooHigh'] });
  assert.ok(!earned([...nine, broken]).includes('clean_ten'));
  assert.ok(earned([...nine, trade(10)]).includes('clean_ten'));
});

test('a 3R winner', () => {
  assert.ok(!earned([trade(1, { r: 2.9 })]).includes('big_winner'));
  assert.ok(earned([trade(1, { r: 3.2 })]).includes('big_winner'));
});

test('a week of journaling, ending today', () => {
  const week = [24, 25, 26, 27, 28, 29, 30].map((d) => trade(d));
  const got = earned(week, new Date(Date.UTC(2026, 8, 30, 12)));
  assert.ok(got.includes('streak_7'));
  assert.ok(!got.includes('streak_30'));
});

test('iron discipline needs twenty trades, not two', () => {
  assert.ok(!earned([trade(1), trade(2)]).includes('iron_discipline'));
  const twenty = Array.from({ length: 20 }, (_, i) => trade(i + 1));
  assert.ok(earned(twenty).includes('iron_discipline'));
});

test('once earned, kept — and in order, with ids from newer versions kept', () => {
  assert.deepEqual(keepAchievements(['streak_7'], ['first_trade']), ['first_trade', 'streak_7']);
  assert.deepEqual(keepAchievements(undefined, ['ranked', 'first_trade']), ['first_trade', 'ranked']);
  assert.deepEqual(keepAchievements(['someday_new'], ['first_trade']), ['first_trade', 'someday_new']);
});
