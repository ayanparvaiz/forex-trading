// Push notifications: who is told what, and who is not — against an
// in-memory Firestore and a pretend FCM.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { MAX_PUSHES, dailyReminder, forgetOldAnnouncements, notify } from '../src/notify.js';
import { memoryStore } from './memory-store.js';

const NOW = Date.parse('2026-09-26T10:00:00Z');
const ago = (minutes) => new Date(NOW - minutes * 60_000).toISOString();

/** Me and Ana talk; Bo is in the room; everyone has a phone. */
function world() {
  return new Map(Object.entries({
    'users/u-me': { displayName: 'Me', username: 'me' },
    'users/u-ana': { displayName: 'Ana', username: 'ana' },
    'users/u-bo': { displayName: 'Bo', username: 'bo' },
    'users/u-me/devices/tok-me': { uid: 'u-me', language: 'en' },
    'users/u-ana/devices/tok-ana': { uid: 'u-ana', language: 'en' },
    'users/u-ana/devices/tok-ana-old': { uid: 'u-ana', language: 'en' },
    'users/u-bo/devices/tok-bo': { uid: 'u-bo', language: 'bn' },

    'chats/ana-me': { uids: ['u-me', 'u-ana'] },
    'chats/ana-me/messages/m1': { senderUid: 'u-me', text: 'hi Ana', sentAt: ago(1), unsent: false },
    'chats/ana-me/messages/m-old': { senderUid: 'u-me', text: 'old', sentAt: ago(30), unsent: false },
    'chats/ana-me/messages/m-gone': { senderUid: 'u-me', text: '', sentAt: ago(1), unsent: true },
    'chats/ana-me/messages/m-post': {
      senderUid: 'u-me', text: 'look', sentAt: ago(1), unsent: false,
      attachment: { type: 'post', postId: 'p1', authorUid: 'u-bo' },
    },

    'rooms/global': { memberCount: 3 },
    'rooms/global/members/u-me': {},
    'rooms/global/members/u-ana': {},
    'rooms/global/members/u-bo': {},
    'rooms/global/messages/g1': { senderUid: 'u-me', senderName: 'Me', text: 'hello all', sentAt: ago(1), unsent: false },

    'connections/ana-me': { fromUid: 'u-me', toUid: 'u-ana', accepted: false, requestedAt: ago(1) },
    'connections/bo-me': { fromUid: 'u-bo', toUid: 'u-me', accepted: true, requestedAt: ago(600), uids: ['u-bo', 'u-me'] },
    'posts/p9': { authorUid: 'u-me', lesson: 'waited for the retest', postedAt: ago(1) },
  }));
}

/** Pretend FCM: remembers what it was given; one phone has gone away. */
function fcm() {
  const sent = [];
  const push = async (message) => {
    sent.push(message);
    return message.token === 'tok-ana-old' ? 'gone' : 'sent';
  };
  return { sent, push };
}

const run = (docs, caller, event) => {
  const { sent, push } = fcm();
  return notify(memoryStore(docs), push, caller, event, NOW).then((result) => ({ result, sent }));
};

test('a message reaches the other person, on every phone they have', async () => {
  const docs = world();
  const { result, sent } = await run(docs, 'u-me', { type: 'message', chatId: 'ana-me', messageId: 'm1' });
  assert.deepEqual(sent.map((m) => m.token).sort(), ['tok-ana', 'tok-ana-old']);
  assert.equal(sent[0].notification.title, 'Me');
  assert.equal(sent[0].notification.body, 'hi Ana');
  assert.deepEqual(sent[0].data, { type: 'message', chatId: 'ana-me', otherUid: 'u-me', otherUsername: 'me' });
  assert.equal(result.sent, 1);
  // The phone FCM no longer knows is forgotten.
  assert.equal(docs.has('users/u-ana/devices/tok-ana-old'), false);
});

test('never twice for the same message', async () => {
  const docs = world();
  await run(docs, 'u-me', { type: 'message', chatId: 'ana-me', messageId: 'm1' });
  const { result, sent } = await run(docs, 'u-me', { type: 'message', chatId: 'ana-me', messageId: 'm1' });
  assert.equal(sent.length, 0);
  assert.equal(result.skipped, 'already told');
});

test('nothing for a message that is not yours, old, unsent, or not in your chat', async () => {
  for (const [caller, messageId] of [['u-ana', 'm1'], ['u-me', 'm-old'], ['u-me', 'm-gone'], ['u-bo', 'm1']]) {
    const { sent } = await run(world(), caller, { type: 'message', chatId: 'ana-me', messageId });
    assert.equal(sent.length, 0, `${caller} ${messageId}`);
  }
});

test('nothing when they muted the chat or blocked you', async () => {
  const muted = world();
  muted.set('users/u-ana/chatPrefs/ana-me', { mutedUntil: ago(-60) });
  assert.equal((await run(muted, 'u-me', { type: 'message', chatId: 'ana-me', messageId: 'm1' })).sent.length, 0);

  const expired = world();
  expired.set('users/u-ana/chatPrefs/ana-me', { mutedUntil: ago(5) });
  assert.equal((await run(expired, 'u-me', { type: 'message', chatId: 'ana-me', messageId: 'm1' })).sent.length, 2);

  const blocked = world();
  blocked.set('users/u-ana/blocks/u-me', { username: 'me' });
  assert.equal((await run(blocked, 'u-me', { type: 'message', chatId: 'ana-me', messageId: 'm1' })).sent.length, 0);
});

test('a shared post says so', async () => {
  const { sent } = await run(world(), 'u-me', { type: 'message', chatId: 'ana-me', messageId: 'm-post' });
  assert.equal(sent[0].notification.body, '📊 Post · look');
});

test('the Global room tells its other members, each in their language', async () => {
  const docs = world();
  const { sent } = await run(docs, 'u-me', { type: 'room', roomId: 'global', messageId: 'g1' });
  const byToken = Object.fromEntries(sent.map((m) => [m.token, m]));
  assert.equal(byToken['tok-me'], undefined, 'not the sender');
  assert.equal(byToken['tok-ana'].notification.title, 'Global');
  assert.equal(byToken['tok-ana'].notification.body, 'Me: hello all');
  assert.equal(byToken['tok-bo'].notification.title, 'গ্লোবাল');
  assert.deepEqual(byToken['tok-bo'].data, { type: 'room', roomId: 'global' });
});

test('not members who muted the room, and not anyone who left', async () => {
  const docs = world();
  docs.set('users/u-bo/chatPrefs/global', { mutedUntil: '9999-12-31T00:00:00Z' });
  docs.delete('rooms/global/members/u-ana');
  const { sent } = await run(docs, 'u-me', { type: 'room', roomId: 'global', messageId: 'g1' });
  assert.equal(sent.length, 0);
});

test("a community's room tells its members, by the community's name", async () => {
  const docs = world();
  docs.set('rooms/c_bulls1', { name: 'Bulls', memberCount: 2 });
  docs.set('rooms/c_bulls1/members/u-me', {});
  docs.set('rooms/c_bulls1/members/u-bo', {});
  docs.set('rooms/c_bulls1/messages/b1', { senderUid: 'u-me', senderName: 'Me', text: 'hi bulls', sentAt: ago(1), unsent: false });
  const { sent } = await run(docs, 'u-me', { type: 'room', roomId: 'c_bulls1', messageId: 'b1' });
  assert.deepEqual(sent.map((m) => m.token), ['tok-bo']);
  assert.equal(sent[0].notification.title, 'Bulls');
  assert.equal(sent[0].notification.body, 'Me: hi bulls');
  assert.deepEqual(sent[0].data, { type: 'room', roomId: 'c_bulls1' });

  // No such room, no such message: nothing.
  const nowhere = await run(docs, 'u-me', { type: 'room', roomId: 'c_bears1', messageId: 'b1' });
  assert.equal(nowhere.sent.length, 0);
});

test('a connection request, and its acceptance', async () => {
  const request = await run(world(), 'u-me', { type: 'connectionRequest', pair: 'ana-me' });
  assert.equal(request.sent[0].notification.body, 'sent you a connection request');
  assert.deepEqual(request.sent[0].data, { type: 'profile', username: 'me' });

  // Only its sender can announce a request.
  assert.equal((await run(world(), 'u-ana', { type: 'connectionRequest', pair: 'ana-me' })).sent.length, 0);

  // bo asked me; I accepted — bo hears, and it opens our chat.
  const accepted = await run(world(), 'u-me', { type: 'connectionAccepted', pair: 'bo-me' });
  assert.deepEqual(accepted.sent.map((m) => m.token), ['tok-bo']);
  assert.equal(accepted.sent[0].notification.body, 'আপনার কানেকশন রিকোয়েস্ট অ্যাকসেপ্ট করেছেন');
  assert.deepEqual(accepted.sent[0].data, { type: 'message', chatId: 'bo-me', otherUid: 'u-me', otherUsername: 'me' });

  // Nor can the one who asked announce the acceptance.
  assert.equal((await run(world(), 'u-bo', { type: 'connectionAccepted', pair: 'bo-me' })).sent.length, 0);
});

test('a new post goes to connections, not to pending requests', async () => {
  const docs = world();
  docs.get('connections/ana-me').uids = ['u-me', 'u-ana'];
  const { sent } = await run(docs, 'u-me', { type: 'post', postId: 'p9' });
  assert.deepEqual(sent.map((m) => m.token), ['tok-bo']);
  assert.equal(sent[0].notification.body, 'নতুন পোস্ট: waited for the retest');
  assert.deepEqual(sent[0].data, { type: 'post', postId: 'p9' });

  assert.equal((await run(world(), 'u-ana', { type: 'post', postId: 'p9' })).sent.length, 0);
});

test("a community's post goes only to connections who are in it", async () => {
  const docs = world();
  Object.assign(docs.get('connections/ana-me'), { uids: ['u-me', 'u-ana'], accepted: true });
  docs.set('posts/p-c', { authorUid: 'u-me', lesson: 'members only', postedAt: ago(1), community: 'bulls1' });
  docs.set('communities/bulls1/members/u-ana', { role: 'member' });
  const { sent } = await run(docs, 'u-me', { type: 'post', postId: 'p-c' });
  // Ana is in it, on both her phones; Bo is connected but not a member.
  assert.deepEqual(sent.map((m) => m.token).sort(), ['tok-ana', 'tok-ana-old']);
});

test('never more than the cap in one request', async () => {
  const docs = world();
  for (let i = 0; i < MAX_PUSHES + 10; i++) {
    docs.set(`users/u-ana/devices/extra-${i}`, { uid: 'u-ana', language: 'en' });
  }
  const { sent } = await run(docs, 'u-me', { type: 'message', chatId: 'ana-me', messageId: 'm1' });
  assert.equal(sent.length, MAX_PUSHES);
});

test('nonsense is turned away', async () => {
  for (const event of [{}, { type: 'x' }, { type: 'message', chatId: '../users', messageId: 'm1' }, { type: 'room', roomId: 'other', messageId: 'g1' }]) {
    const { sent } = await run(world(), 'u-me', event);
    assert.equal(sent.length, 0, JSON.stringify(event));
  }
});

test('the morning reminder goes to each language', async () => {
  const { sent, push } = fcm();
  await dailyReminder(push);
  assert.deepEqual(sent.map((m) => m.topic), ['daily_bn', 'daily_en']);
});

test('old announcements are forgotten, recent ones kept', async () => {
  const docs = world();
  docs.set('pushLog/old', { at: ago(5 * 24 * 60) });
  docs.set('pushLog/new', { at: ago(10) });
  await forgetOldAnnouncements(memoryStore(docs), NOW);
  assert.equal(docs.has('pushLog/old'), false);
  assert.equal(docs.has('pushLog/new'), true);
});
