import { test } from 'node:test';
import assert from 'node:assert/strict';

import { weekId, weeklyStats } from '../src/weekly.js';

test('weeks are ISO weeks in Dhaka time', () => {
  // Thursday 1 October 2026, noon in Dhaka.
  assert.equal(weekId(Date.parse('2026-10-01T06:00:00Z')), '2026-W40');
  // Sunday night in Dhaka is still the same week…
  assert.equal(weekId(Date.parse('2026-10-04T17:59:00Z')), '2026-W40');
  // …and a minute after midnight Dhaka, Monday, the next — though in UTC
  // it is still Sunday.
  assert.equal(weekId(Date.parse('2026-10-04T18:01:00Z')), '2026-W41');
  // The first days of January can belong to the last week of the year
  // before, and the last of December to the first of the next.
  assert.equal(weekId(Date.parse('2027-01-01T06:00:00Z')), '2026-W53');
  assert.equal(weekId(Date.parse('2025-12-31T06:00:00Z')), '2026-W01');
});

function trade(closedAt, violations = []) {
  return {
    symbol: 'EUR/USD',
    direction: 'buy',
    lots: 0.1,
    entryPrice: 1.1,
    stopPrice: 1.098,
    exitPrice: 1.10408,
    openedAt: closedAt,
    closedAt,
    violations,
  };
}

test("only this week's trades, and three of them to be on the board", () => {
  const now = new Date('2026-10-01T06:00:00Z');
  const lastWeek = trade('2026-09-25T06:00:00Z');
  const two = [trade('2026-09-28T06:00:00Z'), trade('2026-09-29T06:00:00Z', ['movedStop'])];
  const notYet = weeklyStats([lastWeek, ...two], now);
  assert.equal(notYet.weekTrades, 2);
  assert.equal(notYet.weekBoard, '');
  assert.equal(notYet.weekScore, (100 + 65) / 2);

  const three = weeklyStats([lastWeek, ...two, trade('2026-09-30T06:00:00Z')], now);
  assert.equal(three.weekBoard, '2026-W40');
  assert.equal(three.weekTrades, 3);
  assert.ok(three.weekR > 0);
});

test('a quiet week: nothing, and nothing on the board', () => {
  const s = weeklyStats([trade('2026-09-01T06:00:00Z')], new Date('2026-10-01T06:00:00Z'));
  assert.deepEqual(s, {
    weekBoard: '',
    weekScore: 100,
    weekTrades: 0,
    weekR: 0,
    lastWeekBoard: '',
    lastWeekScore: 100,
    lastWeekTrades: 0,
  });
});

test("last week's numbers, final, beside this week's", () => {
  const now = new Date('2026-10-01T06:00:00Z'); // W40
  const s = weeklyStats(
    [
      trade('2026-09-22T06:00:00Z'),
      trade('2026-09-23T06:00:00Z', ['revengeTrade']),
      trade('2026-09-24T06:00:00Z'),
      trade('2026-09-30T06:00:00Z'),
    ],
    now,
  );
  assert.equal(s.lastWeekBoard, '2026-W39');
  assert.equal(s.lastWeekTrades, 3);
  assert.equal(s.lastWeekScore, (100 + 75 + 100) / 3);
  assert.equal(s.weekTrades, 1);
});
