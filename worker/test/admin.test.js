// The admin panel's requests against an in-memory Firestore, with sign-ins
// and pushes faked.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { AdminError, adminAction } from '../src/admin.js';
import { memoryStore } from './memory-store.js';

const ADMIN = 'uAdmin';

function world() {
  return new Map(Object.entries({
    [`admins/${ADMIN}`]: { addedAt: 1 },
    'admins/uOther': { addedAt: 1 },
    [`users/${ADMIN}`]: { username: 'boss' },
    'users/uAna': { username: 'ana', communityId: 'bulls1' },
    'users/uBo': { username: 'bo', communityId: 'bulls1' },
    'usernames/ana': { uid: 'uAna' },

    'posts/p1': { authorUid: 'uAna', commentCount: 2, claps: 1 },
    'posts/p1/comments/c1': { authorUid: 'uBo', body: 'nice' },
    'posts/p1/comments/c2': { authorUid: 'uAna', body: 'thanks' },
    'posts/p1/claps/uBo': { uid: 'uBo' },
    'posts/p1/views/uBo': { at: 1 },
    'posts/p2': { authorUid: 'uBo' },

    'rooms/global': { lastMessage: { id: 'm2', senderUid: 'uAna', text: 'buy now!!' } },
    'rooms/global/messages/m1': { senderUid: 'uBo', senderName: 'Bo', text: 'hi', unsent: false },
    'rooms/global/messages/m2': {
      senderUid: 'uAna', senderName: 'Ana', text: 'buy now!!', unsent: false,
      attachment: { type: 'post', postId: 'p2' },
    },

    'reports/r1': { status: 'open', targetUid: 'uAna' },

    'communities/bulls1': { createdBy: 'uAna', memberCount: 2, name: 'Bulls' },
    'communities/bulls1/members/uAna': { role: 'admin' },
    'communities/bulls1/members/uBo': { role: 'member' },
    'rooms/c_bulls1': { memberCount: 2 },
    'rooms/c_bulls1/members/uAna': {},
    'rooms/c_bulls1/members/uBo': {},
    'communityNames/bulls': { communityId: 'bulls1' },
  }));
}

function fakes() {
  const calls = [];
  return {
    calls,
    auth: {
      setDisabled: async (uid, disabled) => calls.push(['disable', uid, disabled]),
      remove: async (uid) => calls.push(['remove', uid]),
    },
    push: async (m) => calls.push(['push', m.topic, m.notification.title]),
  };
}

const run = (docs, body, caller = ADMIN) => {
  const f = fakes();
  return adminAction(memoryStore(docs), f, caller, body, new Date('2026-10-04T10:00:00Z'))
    .then((result) => ({ result, calls: f.calls }));
};

test('only admins get anything done', async () => {
  await assert.rejects(run(world(), { action: 'whoami' }, 'uAna'), (e) => e instanceof AdminError && e.status === 403);
  assert.deepEqual((await run(world(), { action: 'whoami' })).result, { admin: true });
  await assert.rejects(run(world(), { action: 'nonsense' }), (e) => e.status === 400);
});

test('a ban stops the sign-in and marks the profile; lifted, both undone', async () => {
  const docs = world();
  const { calls } = await run(docs, { action: 'ban', uid: 'uAna', banned: true });
  assert.deepEqual(calls, [['disable', 'uAna', true]]);
  assert.equal(docs.get('users/uAna').banned, true);
  await run(docs, { action: 'ban', uid: 'uAna', banned: false });
  assert.equal(docs.get('users/uAna').banned, false);
});

test('never yourself, never another admin', async () => {
  for (const uid of [ADMIN, 'uOther']) {
    await assert.rejects(run(world(), { action: 'ban', uid, banned: true }), (e) => e.status === 400);
    await assert.rejects(run(world(), { action: 'deleteUser', uid }), (e) => e.status === 400);
  }
});

test('deleting an account erases it, then its sign-in', async () => {
  const docs = world();
  const { calls } = await run(docs, { action: 'deleteUser', uid: 'uBo' });
  assert.equal(docs.has('users/uBo'), false);
  assert.equal(docs.has('posts/p2'), false, 'their posts go too');
  assert.equal(docs.has('communities/bulls1/members/uBo'), false);
  assert.deepEqual(calls, [['remove', 'uBo']]);
});

test('a post goes with its comments, likes and views', async () => {
  const docs = world();
  await run(docs, { action: 'deletePost', postId: 'p1' });
  for (const p of ['posts/p1', 'posts/p1/comments/c1', 'posts/p1/claps/uBo', 'posts/p1/views/uBo']) {
    assert.equal(docs.has(p), false, p);
  }
  assert.ok(docs.has('posts/p2'));
});

test('a comment goes, and the count with it', async () => {
  const docs = world();
  await run(docs, { action: 'deleteComment', postId: 'p1', commentId: 'c1' });
  assert.equal(docs.has('posts/p1/comments/c1'), false);
  assert.equal(docs.get('posts/p1').commentCount, 1);
  // Gone already: nothing to do.
  await run(docs, { action: 'deleteComment', postId: 'p1', commentId: 'c1' });
  assert.equal(docs.get('posts/p1').commentCount, 1);
});

test("a room message is taken down as removed, and the room's preview with it", async () => {
  const docs = world();
  await run(docs, { action: 'removeMessage', roomId: 'global', messageId: 'm2' });
  const m = docs.get('rooms/global/messages/m2');
  assert.deepEqual([m.text, m.unsent, m.removed, 'attachment' in m], ['', true, true, false]);
  assert.deepEqual(docs.get('rooms/global').lastMessage, {
    id: 'm2', senderUid: 'uAna', senderName: 'Ana', text: '', unsent: true,
  });
  // An older one leaves the preview alone.
  await run(docs, { action: 'removeMessage', roomId: 'global', messageId: 'm1' });
  assert.equal(docs.get('rooms/global').lastMessage.id, 'm2');
  await assert.rejects(run(docs, { action: 'removeMessage', roomId: 'nope', messageId: 'm1' }), (e) => e.status === 400);
});

test('a report is resolved by whom and when, or opened again', async () => {
  const docs = world();
  await run(docs, { action: 'resolveReport', reportId: 'r1', status: 'resolved' });
  assert.equal(docs.get('reports/r1').status, 'resolved');
  assert.equal(docs.get('reports/r1').resolvedBy, ADMIN);
  await run(docs, { action: 'resolveReport', reportId: 'r1', status: 'open' });
  assert.deepEqual(docs.get('reports/r1'), { status: 'open', targetUid: 'uAna' });
});

test('a community locked, someone removed, then the whole of it deleted', async () => {
  const docs = world();
  await run(docs, { action: 'community', communityId: 'bulls1', op: 'lock' });
  assert.equal(docs.get('communities/bulls1').locked, true);
  await assert.rejects(run(docs, { action: 'community', communityId: 'bulls1', op: 'remove', uid: 'uAna' }), (e) => e.status === 400);
  await run(docs, { action: 'community', communityId: 'bulls1', op: 'remove', uid: 'uBo' });
  assert.equal(docs.has('communities/bulls1/members/uBo'), false);
  assert.equal(docs.get('users/uBo').communityId, '');
  await run(docs, { action: 'community', communityId: 'bulls1', op: 'delete' });
  assert.equal(docs.has('communities/bulls1'), false);
  assert.equal(docs.has('rooms/c_bulls1'), false);
});

test('a broadcast goes to every phone, in each language', async () => {
  const docs = world();
  const { calls, result } = await run(docs, {
    action: 'broadcast',
    bn: { title: 'নতুন আপডেট', body: 'নতুন ফিচার এসেছে' },
    en: { title: 'New update', body: 'New features are here' },
  });
  assert.deepEqual(result, { sent: 2 });
  assert.deepEqual(calls, [['push', 'daily_bn', 'নতুন আপডেট'], ['push', 'daily_en', 'New update']]);
  const kept = [...docs.keys()].filter((k) => k.startsWith('announcements/'));
  assert.equal(kept.length, 1, 'kept for the panel');
  assert.deepEqual(docs.get(kept[0]).en, { title: 'New update', body: 'New features are here' });
  assert.equal(docs.get(kept[0]).sentBy, ADMIN);
  await assert.rejects(run(world(), { action: 'broadcast', bn: { title: '', body: 'x' }, en: { title: 'x', body: 'x' } }), (e) => e.status === 400);
});
