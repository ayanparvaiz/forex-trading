import { test } from 'node:test';
import assert from 'node:assert/strict';

import { crownChampion, monthJustEnded, communityPoints, rankedBoard } from '../src/champion.js';
import { memoryStore } from './memory-store.js';

// 1 October 2026, 09:00 in Dhaka — when the daily run goes.
const OCT_1 = Date.UTC(2026, 9, 1, 3);

function world() {
  const docs = new Map();
  const user = (id, score, trades, communityId, ranked = true) =>
    docs.set(`users/${id}`, { disciplineScore: score, tradeCount: trades, communityId, ranked });
  user('u1', 95, 40, 'bulls1'); // 50
  user('u2', 90, 30, 'bears1'); // 49
  user('u3', 88, 20, 'bears1'); // 48
  user('u4', 85, 10, 'bulls1'); // 47
  user('u5', 99, 90, 'bulls1', false); // not ranked: no points
  docs.set('communities/bulls1', { name: 'Bulls', memberCount: 3 });
  docs.set('communities/bears1', { name: 'Bears', memberCount: 2, titles: ['2026-08'] });
  return docs;
}

test('the month just ended, by the Dhaka calendar', () => {
  assert.deepEqual(monthJustEnded(OCT_1), { month: '2026-09', day: 1 });
  // 30 September 19:00 UTC is already 1 October in Dhaka.
  assert.deepEqual(monthJustEnded(Date.UTC(2026, 8, 30, 19)), { month: '2026-09', day: 1 });
  assert.deepEqual(monthJustEnded(Date.UTC(2027, 0, 2, 3)), { month: '2026-12', day: 2 });
});

test("points as the app counts them, on the app's board order", () => {
  const board = rankedBoard([
    { disciplineScore: 80, tradeCount: 5, communityId: 'a' },
    { disciplineScore: 80, tradeCount: 9, communityId: 'b' },
    { disciplineScore: 90, tradeCount: 1, communityId: '' },
  ]);
  assert.deepEqual([...communityPoints(board)], [['b', 49], ['a', 48]]);
});

test('the top community is crowned, once, with the month as a title', async () => {
  const docs = world();
  const result = await crownChampion(memoryStore(docs), OCT_1);
  // Bears: 49 + 48 = 97; Bulls: 50 + 47 = 97 — a tie, to the bigger one.
  assert.deepEqual(result, { month: '2026-09', communityId: 'bulls1', points: 97 });
  assert.deepEqual(docs.get('champions/2026-09'), { month: '2026-09', communityId: 'bulls1', name: 'Bulls', points: 97 });
  assert.deepEqual(docs.get('communities/bulls1').titles, ['2026-09']);

  const again = await crownChampion(memoryStore(docs), OCT_1 + 86_400_000);
  assert.equal(again.skipped, 'already crowned');
  assert.deepEqual(docs.get('communities/bulls1').titles, ['2026-09']);
});

test('a title is added to the ones before it', async () => {
  const docs = world();
  docs.set('users/u2', { ...docs.get('users/u2'), disciplineScore: 99 });
  await crownChampion(memoryStore(docs), OCT_1);
  assert.deepEqual(docs.get('communities/bears1').titles, ['2026-08', '2026-09']);
});

test('not mid-month; and with nobody ranked, nobody is crowned', async () => {
  const docs = world();
  const mid = await crownChampion(memoryStore(docs), Date.UTC(2026, 9, 15, 3));
  assert.equal(mid.skipped, 'not the start of a month');
  assert.equal(docs.has('champions/2026-09'), false);

  for (const id of ['u1', 'u2', 'u3', 'u4']) docs.set(`users/${id}`, { ...docs.get(`users/${id}`), ranked: false });
  const none = await crownChampion(memoryStore(docs), OCT_1);
  assert.equal(none.communityId, '');
  assert.equal(docs.get('champions/2026-09').communityId, '');
});
