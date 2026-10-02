import { test } from 'node:test';
import assert from 'node:assert/strict';

import { dhakaDay, lastJournalDay, streakReminders } from '../src/streak.js';
import { memoryStore } from './memory-store.js';

test('days are Dhaka days', () => {
  assert.equal(dhakaDay(Date.parse('2026-10-02T17:59:00Z')), '2026-10-02');
  assert.equal(dhakaDay(Date.parse('2026-10-02T18:01:00Z')), '2026-10-03');
});

test('the last day a lesson was written, closed trades only', () => {
  assert.equal(lastJournalDay([]), '');
  assert.equal(
    lastJournalDay([
      { closedAt: '2026-09-30T06:00:00Z', lesson: 'waited' },
      { closedAt: '2026-10-01T06:00:00Z', lesson: '' },
      { closedAt: null, lesson: 'open' },
      { closedAt: '2026-10-01T19:00:00Z', lesson: 'late, Dhaka time' },
    ]),
    '2026-10-02',
  );
});

test('a streak ending tonight hears so; one already kept today does not', async () => {
  // 8 pm in Dhaka on 2 October.
  const now = Date.parse('2026-10-02T14:00:00Z');
  const docs = new Map(Object.entries({
    'users/u-ana': { journalDay: '2026-10-01', journalStreak: 6 },
    'users/u-bo': { journalDay: '2026-10-02', journalStreak: 7 },
    'users/u-cy': { journalDay: '2026-09-28', journalStreak: 0 },
    'users/u-ana/devices/tok-ana': { uid: 'u-ana', language: 'en' },
    'users/u-bo/devices/tok-bo': { uid: 'u-bo', language: 'bn' },
  }));
  const sent = [];
  const n = await streakReminders(memoryStore(docs), async (m) => {
    sent.push(m);
    return 'sent';
  }, now);
  assert.equal(n, 1);
  assert.equal(sent[0].token, 'tok-ana');
  assert.equal(sent[0].notification.title, '🔥 6-day streak');
});
