// Erasing an account against an in-memory Firestore: what goes, what stays,
// and that stopping part-way and starting again ends in the same place.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { eraseAccount } from '../src/erase.js';
import { TryAgain } from '../src/firestore.js';
import { memoryStore } from './memory-store.js';

const ME = 'u-me';

/** Me, ana and bo, and a bit of everything between us. */
function world() {
  return new Map(Object.entries({
    'users/u-me': { username: 'me' },
    'users/u-me/trades/t1': { symbol: 'EUR/USD' },
    'users/u-me/trades/t2': { symbol: 'XAU/USD' },
    'users/u-me/blocks/u-bo': { username: 'bo' },
    'users/u-ana': { username: 'ana' },
    'users/u-ana/trades/t1': { symbol: 'GBP/USD' },
    'users/u-ana/blocks/u-me': { username: 'me' },
    'users/u-ana/blocks/u-bo': { username: 'bo' },
    'users/u-bo': { username: 'bo' },
    'usernames/me': { uid: ME },
    'usernames/ana': { uid: 'u-ana' },
    'presence/u-me': { lastActiveAt: 1 },
    'presence/u-ana': { lastActiveAt: 1 },

    // My post, with ana's comment, like and view on it.
    'posts/p-me': { authorUid: ME, commentCount: 1, claps: 1 },
    'posts/p-me/comments/c1': { authorUid: 'u-ana' },
    'posts/p-me/claps/u-ana': { uid: 'u-ana' },
    'posts/p-me/views/u-ana': {},

    // Ana's post, with my comment and like, and bo's comment.
    'posts/p-ana': { authorUid: 'u-ana', commentCount: 2, claps: 1, reach: 2 },
    'posts/p-ana/comments/c2': { authorUid: ME },
    'posts/p-ana/comments/c3': { authorUid: 'u-bo' },
    'posts/p-ana/claps/u-me': { uid: ME },
    'posts/p-ana/views/u-me': {},

    // A count that has already drifted below the truth.
    'posts/p-drift': { authorUid: 'u-ana', commentCount: 0 },
    'posts/p-drift/comments/c4': { authorUid: ME },

    // A comment left behind under a post that is gone.
    'posts/p-gone/comments/c5': { authorUid: ME },

    'connections/ana-me': { uids: [ME, 'u-ana'] },
    'connections/ana-bo': { uids: ['u-ana', 'u-bo'] },
    'chats/ana-me': { uids: [ME, 'u-ana'] },
    'chats/ana-me/messages/m1': { senderUid: 'u-ana' },
    'chats/ana-me/messages/m2': { senderUid: ME },
    'chats/ana-bo': { uids: ['u-ana', 'u-bo'] },
    'chats/ana-bo/messages/m1': { senderUid: 'u-bo' },

    'notifications/n1': { recipientUid: ME, actorUid: 'u-ana' },
    'notifications/n2': { recipientUid: 'u-ana', actorUid: ME },
    'notifications/n3': { recipientUid: 'u-bo', actorUid: 'u-ana' },
    'profileViews/u-me_u-ana': { viewerUid: ME, profileUid: 'u-ana' },
    'profileViews/u-ana_u-me': { viewerUid: 'u-ana', profileUid: ME },
    'profileViews/u-bo_u-ana': { viewerUid: 'u-bo', profileUid: 'u-ana' },

    'reports/r1': { reporterUid: 'u-ana', targetUid: ME },
    'reports/r2': { reporterUid: ME, targetUid: 'u-bo' },

    // The Global room: both of us joined, and my message is the latest.
    'rooms/global': { memberCount: 2, lastMessage: { id: 'g3', senderUid: ME, senderName: 'Me', text: 'bye', unsent: false } },
    'rooms/global/members/u-me': { readAt: 3 },
    'rooms/global/members/u-ana': { readAt: 3 },
    'rooms/global/messages/g1': { senderUid: 'u-ana', senderName: 'Ana', text: 'hello', unsent: false, sentAt: 1 },
    'rooms/global/messages/g2': { senderUid: ME, senderName: 'Me', text: 'hi Ana', unsent: false, sentAt: 2 },
    'rooms/global/messages/g3': { senderUid: ME, senderName: 'Me', text: 'bye', unsent: false, sentAt: 3 },
  }));
}

/** What should be left once I am gone. */
const AFTER = {
  'users/u-ana': { username: 'ana' },
  'users/u-ana/trades/t1': { symbol: 'GBP/USD' },
  'users/u-ana/blocks/u-bo': { username: 'bo' },
  'users/u-bo': { username: 'bo' },
  'usernames/me': { retiredAt: 'SERVER_TIME' },
  'usernames/ana': { uid: 'u-ana' },
  'presence/u-ana': { lastActiveAt: 1 },
  'posts/p-ana': { authorUid: 'u-ana', commentCount: 1, claps: 0, reach: 2 },
  'posts/p-ana/comments/c3': { authorUid: 'u-bo' },
  // Views are not likes: reach counts who saw a post, and stays.
  'posts/p-ana/views/u-me': {},
  'posts/p-drift': { authorUid: 'u-ana', commentCount: 0 },
  'connections/ana-bo': { uids: ['u-ana', 'u-bo'] },
  'chats/ana-bo': { uids: ['u-ana', 'u-bo'] },
  'chats/ana-bo/messages/m1': { senderUid: 'u-bo' },
  'notifications/n3': { recipientUid: 'u-bo', actorUid: 'u-ana' },
  'profileViews/u-bo_u-ana': { viewerUid: 'u-bo', profileUid: 'u-ana' },
  'reports/r1': { reporterUid: 'u-ana', targetUid: ME },
  'reports/r2': { reporterUid: ME, targetUid: 'u-bo' },
  // Counted out, my messages gone, and the preview back on Ana's.
  'rooms/global': { memberCount: 1, lastMessage: { id: 'g1', senderUid: 'u-ana', senderName: 'Ana', text: 'hello', unsent: false } },
  'rooms/global/members/u-ana': { readAt: 3 },
  'rooms/global/messages/g1': { senderUid: 'u-ana', senderName: 'Ana', text: 'hello', unsent: false, sentAt: 1 },
};

const snapshot = (docs) => Object.fromEntries([...docs.entries()].sort());

test('erases everything the policy lists, and nothing else', async () => {
  const docs = world();
  await eraseAccount(memoryStore(docs), ME);
  assert.deepEqual(snapshot(docs), AFTER);
});

test('running it again once it is done changes nothing and costs one read', async () => {
  const docs = world();
  await eraseAccount(memoryStore(docs), ME);
  const store = memoryStore(docs, { budget: 1 });
  await eraseAccount(store, ME);
  assert.deepEqual(snapshot(docs), AFTER);
});

test('stopped part-way again and again, it still ends in the same place', async () => {
  const docs = world();
  let rounds = 0;
  for (;;) {
    rounds++;
    assert.ok(rounds < 20, 'never finished');
    try {
      // Enough for the fixed queries plus a little progress each time.
      await eraseAccount(memoryStore(docs, { budget: 22 }), ME);
      break;
    } catch (error) {
      if (!(error instanceof TryAgain)) throw error;
    }
  }
  assert.ok(rounds > 1, 'the budget never ran out, so resuming was not tested');
  assert.deepEqual(snapshot(docs), AFTER);
});

test("a name someone else holds is never retired", async () => {
  const docs = world();
  // A profile pointing at a username whose claim is not this account's.
  docs.set('usernames/me', { uid: 'u-someone-else' });
  await eraseAccount(memoryStore(docs), ME);
  assert.deepEqual(docs.get('usernames/me'), { uid: 'u-someone-else' });
  assert.equal(docs.has('users/u-me'), false);
});

test('a post deleted mid-way stops the commit rather than creating a ghost', async () => {
  const docs = world();
  const store = memoryStore(docs);
  const getAll = store.getAll;
  // The post disappears between reading its count and writing it.
  store.getAll = async (paths, fields) => {
    const out = await getAll(paths, fields);
    docs.delete('posts/p-ana');
    return out;
  };
  await assert.rejects(eraseAccount(store, ME), TryAgain);
  assert.equal(docs.has('posts/p-ana'), false);

  // The next call sees it gone and only deletes what was left on it.
  await eraseAccount(memoryStore(docs), ME);
  assert.equal(docs.has('posts/p-ana'), false);
  assert.equal(docs.has('posts/p-ana/comments/c2'), false);
  assert.equal(docs.has('users/u-me'), false);
});

test('more than one page of trades, and more than one commit', async () => {
  const docs = world();
  for (let i = 0; i < 1234; i++) docs.set(`users/u-me/trades/x${i}`, {});
  await eraseAccount(memoryStore(docs), ME);
  assert.deepEqual(snapshot(docs), AFTER);
});

test("a room whose latest is someone else's keeps its preview", async () => {
  const docs = world();
  docs.get('rooms/global').lastMessage = { id: 'g1', senderUid: 'u-ana', senderName: 'Ana', text: 'hello', unsent: false };
  await eraseAccount(memoryStore(docs), ME);
  assert.equal(docs.get('rooms/global').lastMessage.id, 'g1');
  assert.equal(docs.get('rooms/global').memberCount, 1);
});

test('someone who never joined leaves the count alone', async () => {
  const docs = world();
  docs.delete('rooms/global/members/u-me');
  docs.get('rooms/global').memberCount = 1;
  await eraseAccount(memoryStore(docs), ME);
  assert.equal(docs.get('rooms/global').memberCount, 1);
});

test('a room left with no messages at all shows none', async () => {
  const docs = world();
  docs.delete('rooms/global/messages/g1');
  await eraseAccount(memoryStore(docs), ME);
  assert.equal(docs.get('rooms/global').lastMessage, null);
});

test('out of their community and its room, and out of rooms they left before', async () => {
  const docs = world();
  docs.get('users/u-me').communityId = 'bulls1';
  docs.set('communities/bulls1', { name: 'Bulls', memberCount: 2, createdBy: ME });
  docs.set('communities/bulls1/members/u-me', { role: 'admin' });
  docs.set('communities/bulls1/members/u-ana', { role: 'member' });
  docs.set('rooms/c_bulls1', {
    name: 'Bulls',
    memberCount: 2,
    lastMessage: { id: 'b2', senderUid: ME, senderName: 'Me', text: 'mine', unsent: false },
  });
  docs.set('rooms/c_bulls1/members/u-me', {});
  docs.set('rooms/c_bulls1/members/u-ana', {});
  docs.set('rooms/c_bulls1/messages/b1', { senderUid: 'u-ana', senderName: 'Ana', text: 'hers', unsent: false, sentAt: 1 });
  docs.set('rooms/c_bulls1/messages/b2', { senderUid: ME, senderName: 'Me', text: 'mine', unsent: false, sentAt: 2 });
  // A community left long ago, where something of mine is still said.
  docs.set('rooms/c_bears1', { name: 'Bears', memberCount: 1, lastMessage: { id: 'x1', senderUid: 'u-bo' } });
  docs.set('rooms/c_bears1/messages/x0', { senderUid: ME, text: 'old', sentAt: 0 });
  docs.set('rooms/c_bears1/messages/x1', { senderUid: 'u-bo', text: 'still here', sentAt: 1 });

  await eraseAccount(memoryStore(docs), ME);

  // The community stays, for Ana, one member lighter.
  assert.deepEqual(docs.get('communities/bulls1'), { name: 'Bulls', memberCount: 1, createdBy: ME });
  assert.equal(docs.has('communities/bulls1/members/u-me'), false);
  assert.equal(docs.has('communities/bulls1/members/u-ana'), true);
  // Its room: counted out, my words gone, Ana's shown instead.
  assert.equal(docs.get('rooms/c_bulls1').memberCount, 1);
  assert.equal(docs.get('rooms/c_bulls1').lastMessage.id, 'b1');
  assert.equal(docs.has('rooms/c_bulls1/members/u-me'), false);
  assert.equal(docs.has('rooms/c_bulls1/messages/b2'), false);
  // The old one: my words gone, nothing else touched.
  assert.equal(docs.has('rooms/c_bears1/messages/x0'), false);
  assert.equal(docs.has('rooms/c_bears1/messages/x1'), true);
  assert.equal(docs.get('rooms/c_bears1').memberCount, 1);
});
