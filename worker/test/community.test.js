// A community's admin removing someone, and deleting it — against an
// in-memory Firestore.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { deleteCommunity, isCommunityId, removeMember } from '../src/community.js';
import { TryAgain } from '../src/firestore.js';
import { memoryStore } from './memory-store.js';

/** Bulls: Ana (admin), Bo and Cy, with a room, messages and posts. Bears: Di. */
function world() {
  return new Map(Object.entries({
    'users/u-ana': { username: 'ana', communityId: 'bulls1' },
    'users/u-bo': { username: 'bo', communityId: 'bulls1' },
    'users/u-cy': { username: 'cy', communityId: 'bulls1' },
    'users/u-di': { username: 'di', communityId: 'bears1' },

    'communities/bulls1': { name: 'Bulls', nameLower: 'bulls', createdBy: 'u-ana', memberCount: 3 },
    'communities/bulls1/members/u-ana': { role: 'admin' },
    'communities/bulls1/members/u-bo': { role: 'member' },
    'communities/bulls1/members/u-cy': { role: 'member' },
    'communityNames/bulls': { communityId: 'bulls1' },
    'rooms/c_bulls1': { name: 'Bulls', memberCount: 3 },
    'rooms/c_bulls1/members/u-ana': {},
    'rooms/c_bulls1/members/u-bo': {},
    'rooms/c_bulls1/members/u-cy': {},
    'rooms/c_bulls1/messages/m1': { senderUid: 'u-bo', text: 'hi' },
    'rooms/c_bulls1/messages/m2': { senderUid: 'u-ana', text: 'welcome' },
    'posts/p1': { authorUid: 'u-bo', community: 'bulls1', commentCount: 1 },
    'posts/p1/comments/c1': { authorUid: 'u-cy' },
    'posts/p1/claps/u-ana': { uid: 'u-ana' },

    'communities/bears1': { name: 'Bears', nameLower: 'bears', createdBy: 'u-di', memberCount: 1 },
    'communities/bears1/members/u-di': { role: 'admin' },
    'communityNames/bears': { communityId: 'bears1' },
    'rooms/c_bears1': { name: 'Bears', memberCount: 1 },
    'rooms/c_bears1/members/u-di': {},
    'posts/p2': { authorUid: 'u-di', community: 'bears1' },
    'posts/p3': { authorUid: 'u-bo', community: 'global' },
  }));
}

test('removing someone takes them out of the community, its room and their profile', async () => {
  const docs = world();
  await removeMember(memoryStore(docs), 'bulls1', 'u-bo');
  assert.equal(docs.has('communities/bulls1/members/u-bo'), false);
  assert.equal(docs.has('rooms/c_bulls1/members/u-bo'), false);
  assert.equal(docs.get('communities/bulls1').memberCount, 2);
  assert.equal(docs.get('rooms/c_bulls1').memberCount, 2);
  assert.equal(docs.get('users/u-bo').communityId, '');
  // What they said stays, as when anyone leaves.
  assert.equal(docs.has('rooms/c_bulls1/messages/m1'), true);
  assert.equal(docs.has('posts/p1'), true);

  // Again: nothing more to do, and the counts stay put.
  await removeMember(memoryStore(docs), 'bulls1', 'u-bo');
  assert.equal(docs.get('communities/bulls1').memberCount, 2);
});

test("removing someone never touches a profile that is in another community", async () => {
  const docs = world();
  await removeMember(memoryStore(docs), 'bulls1', 'u-di');
  assert.equal(docs.get('users/u-di').communityId, 'bears1');
  assert.equal(docs.get('communities/bulls1').memberCount, 3);
});

test('deleting a community: everyone leaves, and all of it goes — nothing else does', async () => {
  const docs = world();
  await deleteCommunity(memoryStore(docs), 'bulls1');
  assert.deepEqual([...docs.keys()].filter((p) => p.includes('bulls') || p.startsWith('posts/p1')), []);
  for (const u of ['u-ana', 'u-bo', 'u-cy']) assert.equal(docs.get(`users/${u}`).communityId, '', u);
  // Bears, Di and a Global post are untouched.
  assert.equal(docs.get('users/u-di').communityId, 'bears1');
  assert.equal(docs.has('communities/bears1/members/u-di'), true);
  assert.equal(docs.has('posts/p2'), true);
  assert.equal(docs.has('posts/p3'), true);
});

test('stopped part-way again and again, a deletion still finishes', async () => {
  const docs = world();
  for (let i = 0; i < 50; i++) docs.set(`rooms/c_bulls1/messages/x${i}`, { senderUid: 'u-bo' });
  let rounds = 0;
  for (;;) {
    rounds++;
    assert.ok(rounds < 30, 'never finished');
    try {
      await deleteCommunity(memoryStore(docs, { budget: 8 }), 'bulls1');
      break;
    } catch (error) {
      if (!(error instanceof TryAgain)) throw error;
      // Locked from the first round on: nobody joins while it goes.
      if (docs.has('communities/bulls1')) assert.equal(docs.get('communities/bulls1').locked, true);
    }
  }
  assert.ok(rounds > 1, 'the budget never ran out, so resuming was not tested');
  assert.equal(docs.has('communities/bulls1'), false);
  assert.equal(docs.get('users/u-cy').communityId, '');
});

test('only community ids are taken', () => {
  assert.equal(isCommunityId('bulls1'), true);
  for (const bad of ['', 'ab', '../users', 'c_bulls1', null, 12]) assert.equal(isCommunityId(bad), false, String(bad));
});
