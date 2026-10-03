// The admin panel's requests against an in-memory Firestore, with sign-ins
// and pushes faked.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { AdminError, adminAction, liftExpiredBans } from '../src/admin.js';
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
    'usernames/bo': { uid: 'uBo' },
    'users/uAna/devices/tokAna': { uid: 'uAna', language: 'en' },

    'posts/p1': { authorUid: 'uAna', commentCount: 2, claps: 1 },
    'posts/p1/comments/c1': { authorUid: 'uBo', authorUsername: 'bo', body: 'nice' },
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
      setPassword: async (uid, password) => calls.push(['password', uid, password]),
    },
    push: async (m) => calls.push(['push', m.topic ?? m.token, m.notification.title, m.notification.body]),
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
  assert.deepEqual(calls, [
    ['push', 'daily_bn', 'নতুন আপডেট', 'নতুন ফিচার এসেছে'],
    ['push', 'daily_en', 'New update', 'New features are here'],
  ]);
  const kept = [...docs.keys()].filter((k) => k.startsWith('announcements/'));
  assert.equal(kept.length, 1, 'kept for the panel');
  assert.deepEqual(docs.get(kept[0]).en, { title: 'New update', body: 'New features are here' });
  assert.equal(docs.get(kept[0]).sentBy, ADMIN);
  await assert.rejects(run(world(), { action: 'broadcast', bn: { title: '', body: 'x' }, en: { title: 'x', body: 'x' } }), (e) => e.status === 400);
});

test('every change goes in the activity log, saying who did what to whom', async () => {
  const docs = world();
  const log = () => [...docs.entries()].filter(([k]) => k.startsWith('adminLog/')).map(([, v]) => v);

  await run(docs, { action: 'whoami' });
  assert.equal(log().length, 0, 'asking is not a change');

  await run(docs, { action: 'deleteComment', postId: 'p1', commentId: 'c1' });
  await run(docs, { action: 'ban', uid: 'uAna', banned: true });
  const [comment, ban] = log();
  assert.deepEqual(
    [comment.action, comment.by, comment.byUsername, comment.author, comment.snippet],
    ['deleteComment', ADMIN, 'boss', 'bo', 'nice'],
  );
  assert.deepEqual([ban.action, ban.uid, ban.username, ban.banned], ['ban', 'uAna', 'ana', true]);
  assert.ok(ban.at instanceof Date);

  // Refused: nothing done, nothing logged.
  await assert.rejects(run(docs, { action: 'ban', uid: ADMIN, banned: true }));
  assert.equal(log().length, 2);
});

test('an account deleted is still named in the log', async () => {
  const docs = world();
  await run(docs, { action: 'deleteUser', uid: 'uBo', username: 'bo' });
  const [entry] = [...docs.entries()].filter(([k]) => k.startsWith('adminLog/')).map(([, v]) => v);
  assert.equal(entry.username, 'bo');
});

test('no action by a name that is not one', async () => {
  for (const action of ['constructor', '__proto__', 'toString']) {
    await assert.rejects(run(world(), { action }), (e) => e.status === 400);
  }
});

const NOW = new Date('2026-10-04T10:00:00Z');
const logOf = (docs) => [...docs.entries()].filter(([k]) => k.startsWith('adminLog/')).map(([, v]) => v);

test('a ban for some days ends by itself; one for good, or lifted, forgets the end', async () => {
  const docs = world();
  const { result } = await run(docs, { action: 'ban', uid: 'uAna', banned: true, days: 7, reason: 'spam links' });
  assert.equal(result.until, '2026-10-11T10:00:00.000Z');
  assert.equal(docs.get('users/uAna').bannedUntil.getTime(), new Date('2026-10-11T10:00:00Z').getTime());
  assert.deepEqual([logOf(docs)[0].days, logOf(docs)[0].reason], [7, 'spam links']);
  assert.equal('reason' in docs.get('users/uAna'), false, 'the reason is not on the public profile');

  for (const days of [2, 0, -1, '7']) {
    await assert.rejects(run(docs, { action: 'ban', uid: 'uAna', banned: true, days }), (e) => e.status === 400);
  }
  await assert.rejects(run(docs, { action: 'ban', uid: 'uAna', banned: false, days: 7 }), (e) => e.status === 400);

  // Not yet: nothing lifted.
  const f = fakes();
  assert.equal(await liftExpiredBans(memoryStore(docs), f.auth, new Date('2026-10-11T09:59:00Z')), 0);
  // Time's up.
  assert.equal(await liftExpiredBans(memoryStore(docs), f.auth, new Date('2026-10-11T10:01:00Z')), 1);
  assert.deepEqual(f.calls, [['disable', 'uAna', false]]);
  assert.equal(docs.get('users/uAna').banned, false);
  assert.equal('bannedUntil' in docs.get('users/uAna'), false);
  const lifted = logOf(docs).find((e) => e.action === 'liftBan');
  assert.deepEqual([lifted.by, lifted.uid, lifted.username], ['system', 'uAna', 'ana']);

  await run(docs, { action: 'ban', uid: 'uBo', banned: true, days: 1 });
  await run(docs, { action: 'ban', uid: 'uBo', banned: true });
  assert.equal('bannedUntil' in docs.get('users/uBo'), false, 'for good now');
});

test('a new password for someone locked out; never a short one, never an admin', async () => {
  const { calls } = await run(world(), { action: 'setPassword', uid: 'uAna', password: 'fresh-start-7' });
  assert.deepEqual(calls, [['password', 'uAna', 'fresh-start-7']]);
  await assert.rejects(run(world(), { action: 'setPassword', uid: 'uAna', password: '12345' }), (e) => e.status === 400);
  await assert.rejects(run(world(), { action: 'setPassword', uid: 'uOther', password: 'long-enough' }), (e) => e.status === 400);
  const docs = world();
  await run(docs, { action: 'setPassword', uid: 'uAna', password: 'fresh-start-7' });
  assert.equal(JSON.stringify(logOf(docs)).includes('fresh-start-7'), false, 'the password is never logged');
});

test('a warning goes to their phones only, in their language, and says how many', async () => {
  const docs = world();
  const { calls, result } = await run(docs, { action: 'warn', uid: 'uAna', message: 'No more links to paid groups, please.' });
  assert.deepEqual(calls, [['push', 'tokAna', 'A warning from the admins', 'No more links to paid groups, please.']]);
  assert.equal(result.phones, 1);
  assert.equal(logOf(docs)[0].snippet, 'No more links to paid groups, please.');
  // No phones: nothing sent, still recorded.
  assert.equal((await run(docs, { action: 'warn', uid: 'uBo', message: 'Be kind.' })).result.phones, 0);
  await assert.rejects(run(docs, { action: 'warn', uid: 'uBo', message: '  ' }), (e) => e.status === 400);
});

test("a name or picture put back to plain", async () => {
  const docs = world();
  docs.set('users/uBo', { ...docs.get('users/uBo'), displayName: 'Rude Name', nameLower: 'rude name', avatarId: 9 });
  await run(docs, { action: 'resetProfile', uid: 'uBo', name: true });
  assert.deepEqual([docs.get('users/uBo').displayName, docs.get('users/uBo').nameLower, docs.get('users/uBo').avatarId], ['bo', 'bo', 9]);
  await run(docs, { action: 'resetProfile', uid: 'uBo', avatar: true });
  assert.equal(docs.get('users/uBo').avatarId, 1);
  assert.deepEqual(logOf(docs).map((e) => e.what), ['name', 'picture']);
  await assert.rejects(run(docs, { action: 'resetProfile', uid: 'uBo' }), (e) => e.status === 400);
});

test('admins are made by username, and taken away by anyone but themselves', async () => {
  const docs = world();
  const { result } = await run(docs, { action: 'addAdmin', username: '@Ana' });
  assert.deepEqual(result, { done: true, uid: 'uAna', username: 'ana' });
  assert.equal(docs.get('admins/uAna').addedBy, ADMIN);
  // Twice is fine.
  await run(docs, { action: 'addAdmin', username: 'ana' });
  await assert.rejects(run(docs, { action: 'addAdmin', username: 'nobody' }), (e) => e.status === 404);
  await assert.rejects(run(docs, { action: 'addAdmin', username: 'x' }), (e) => e.status === 400);
  await assert.rejects(run(docs, { action: 'removeAdmin', uid: ADMIN }), (e) => e.status === 400);
  await run(docs, { action: 'removeAdmin', uid: 'uAna' });
  assert.equal(docs.has('admins/uAna'), false);
  assert.deepEqual(logOf(docs).map((e) => [e.action, e.username]), [['addAdmin', 'ana'], ['addAdmin', 'ana'], ['removeAdmin', 'ana']]);

  docs.set('users/uAna', { ...docs.get('users/uAna'), banned: true });
  await assert.rejects(run(docs, { action: 'addAdmin', username: 'ana' }), (e) => e.status === 400 && /ban/.test(e.message));
});
