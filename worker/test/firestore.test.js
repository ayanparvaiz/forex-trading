// The REST codec is the one place a type mistake would silently corrupt a
// trade — an integer arriving as a string, a missing field arriving as
// undefined — so it is tested on its own.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { decodeFields } from '../src/firestore.js';
import { leaderboardStats } from '../src/stats.js';

// A trade exactly as the Firestore REST API returns it.
const restTrade = {
  symbol: { stringValue: 'EUR/USD' },
  direction: { stringValue: 'buy' },
  lots: { doubleValue: 0.1 },
  entryPrice: { doubleValue: 1.085 },
  stopPrice: { doubleValue: 1.083 },
  targetPrice: { doubleValue: 1.089 },
  openedAt: { stringValue: '2026-09-22T08:00:00.000Z' },
  closedAt: { stringValue: '2026-09-22T11:00:00.000Z' },
  exitPrice: { doubleValue: 1.089 },
  exitReason: { stringValue: 'takeProfit' },
  // Whole numbers come back as integerValue strings, not doubles.
  balanceAtEntry: { integerValue: '10000' },
  reason: { stringValue: 'breakout above the range' },
  lesson: { stringValue: 'waited for the retest' },
  violations: { arrayValue: { values: [{ stringValue: 'noJournal' }] } },
  isShared: { booleanValue: true },
};

test('decodes every field type a trade uses', () => {
  const t = decodeFields(restTrade);

  assert.equal(t.symbol, 'EUR/USD');
  assert.equal(t.lots, 0.1);
  assert.equal(t.balanceAtEntry, 10000);
  assert.equal(typeof t.balanceAtEntry, 'number');
  assert.deepEqual(t.violations, ['noJournal']);
  assert.equal(t.isShared, true);
});

test('null and empty arrays survive', () => {
  const t = decodeFields({
    closedAt: { nullValue: null },
    violations: { arrayValue: {} },
  });

  assert.equal(t.closedAt, null);
  assert.deepEqual(t.violations, []);
});

test('a decoded trade feeds the formula without adjustment', () => {
  // The integerValue lots/balance case in particular: if the codec returned
  // strings, the arithmetic would concatenate instead of add.
  const stats = leaderboardStats(
    [{ id: 'w1', ...decodeFields(restTrade) }],
    new Date('2026-09-22T12:00:00Z'),
  );

  assert.equal(stats.tradeCount, 1);
  assert.equal(stats.badgePoints, 1);
  assert.equal(stats.disciplineScore, 90);
  assert.ok(Math.abs(stats.totalR - 1.96) < 1e-9);
});
