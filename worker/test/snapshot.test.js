import { test } from 'node:test';
import assert from 'node:assert/strict';

import { dhakaDate, takeSnapshot } from '../src/snapshot.js';
import { memoryStore } from './memory-store.js';

const NOW = new Date('2026-10-04T03:00:00Z');
const ago = (h) => new Date(NOW.getTime() - h * 3600_000);

test("a day's numbers, counted and kept under its Dhaka date", async () => {
  const docs = new Map(Object.entries({
    'users/a': { tradeCount: 10 },
    'users/b': { tradeCount: 5 },
    'users/c': {},
    'presence/a': { lastActiveAt: ago(2) },
    'presence/b': { lastActiveAt: ago(3 * 24) },
    'presence/c': { lastActiveAt: ago(20 * 24) },
    'posts/p1': { postedAt: ago(5) },
    'posts/p2': { postedAt: ago(30) },
    'reports/r1': { createdAt: ago(1) },
  }));
  const day = await takeSnapshot(memoryStore(docs), NOW);
  assert.deepEqual(
    [day.date, day.accounts, day.trades, day.active1d, day.active7d, day.active30d, day.posts1d, day.reports1d],
    ['2026-10-04', 3, 15, 1, 2, 3, 1, 1],
  );
  assert.equal(docs.get('stats/2026-10-04').accounts, 3);
  // Again the same day: the same document, brought up to date.
  docs.set('users/d', { tradeCount: 1 });
  await takeSnapshot(memoryStore(docs), NOW);
  assert.equal(docs.get('stats/2026-10-04').accounts, 4);
});

test('the date is the one in Dhaka', () => {
  assert.equal(dhakaDate(Date.parse('2026-10-03T18:30:00Z')), '2026-10-04');
  assert.equal(dhakaDate(Date.parse('2026-10-03T17:59:00Z')), '2026-10-03');
});
