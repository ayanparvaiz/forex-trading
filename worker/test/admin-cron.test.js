// The worker's quarter-hourly work for the admins, against an in-memory
// Firestore.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { adminAction } from '../src/admin.js';
import { autoHideReported, reportAlerts, sendScheduled } from '../src/admin-cron.js';
import { TryAgain } from '../src/firestore.js';
import { memoryStore } from './memory-store.js';

const T0 = new Date('2026-10-04T10:00:00Z');
const later = (min) => new Date(T0.getTime() + min * 60_000);

function world() {
  return new Map(Object.entries({
    'admins/uOwner': { addedAt: 1 },
    'admins/uQuiet': { addedAt: 1, addedBy: 'uOwner', alerts: false },
    'users/uOwner/devices/tokOwner': { uid: 'uOwner', language: 'en' },
    'users/uQuiet/devices/tokQuiet': { uid: 'uQuiet', language: 'bn' },
    'users/uAna': { username: 'ana' },
    'posts/p1': { authorUid: 'uAna', authorUsername: 'ana', lesson: 'join my group', expiresAt: later(7 * 24 * 60) },
    'posts/p2': { authorUid: 'uAna', authorUsername: 'ana', lesson: 'fine post', expiresAt: later(7 * 24 * 60) },
  }));
}

const pushes = () => {
  const sent = [];
  return { sent, push: async (m) => sent.push([m.token ?? m.topic, m.notification.title, m.notification.body]) };
};
const report = (id, reporter, postId, at, status = 'open') => [
  `reports/${id}`, { kind: 'post', postId, reporterUid: reporter, createdAt: at, status },
];

test('new reports reach the admins who want to hear, once', async () => {
  const docs = world();
  const { sent, push } = pushes();
  docs.set(...report('r0', 'x', 'p2', T0));
  // The first run only marks where to start.
  assert.deepEqual(await reportAlerts(memoryStore(docs), push, later(1)), { sent: 0 });
  assert.equal(sent.length, 0);

  docs.set(...report('r1', 'a', 'p1', later(2)));
  docs.set(...report('r2', 'b', 'p1', later(3)));
  docs.set(...report('r3', 'c', 'p1', later(4), 'dismissed'));
  docs.set('support/s1', { uid: 'uAna', text: 'hello', createdAt: later(5), status: 'open' });
  docs.set('helpRequests/pw_uAna', { uid: 'uAna', createdAt: later(6), status: 'open' });
  assert.deepEqual(await reportAlerts(memoryStore(docs), push, later(15)), { sent: 1, reports: 2, support: 1, help: 1 });
  assert.deepEqual(sent, [['tokOwner', 'New in the admin panel', '2 reports, 1 message, 1 password request waiting.']]);

  // Nothing new: nothing sent.
  assert.deepEqual(await reportAlerts(memoryStore(docs), push, later(30)), { sent: 0 });
  assert.equal(sent.length, 1);
});

test('a post enough different people reported comes off the feeds until an admin puts it back', async () => {
  const docs = world();
  docs.set(...report('r1', 'a', 'p1', T0));
  docs.set(...report('r2', 'b', 'p1', T0));
  docs.set(...report('r3', 'b', 'p1', T0)); // the same person twice counts once
  docs.set(...report('r4', 'a', 'p2', T0));
  assert.equal(await autoHideReported(memoryStore(docs), later(5)), 0, 'two people are not three');

  docs.set(...report('r5', 'c', 'p1', T0));
  const was = docs.get('posts/p1').expiresAt;
  assert.equal(await autoHideReported(memoryStore(docs), later(5)), 1);
  const p1 = docs.get('posts/p1');
  assert.deepEqual([p1.hiddenByReports, p1.expiresAt.getTime(), p1.hiddenExpiresAt.getTime()], [true, later(5).getTime(), was.getTime()]);
  const log = [...docs.entries()].filter(([k]) => k.startsWith('adminLog/')).map(([, v]) => v);
  assert.deepEqual([log[0].action, log[0].by, log[0].author, log[0].reports], ['autoHide', 'system', 'ana', 3]);
  assert.equal(await autoHideReported(memoryStore(docs), later(20)), 0, 'hidden once');

  // An admin puts it back, with the week it had.
  await adminAction(memoryStore(docs), { auth: {}, push: async () => {} }, 'uOwner', { action: 'unhide', postId: 'p1' }, later(30));
  assert.equal(docs.get('posts/p1').expiresAt.getTime(), was.getTime());
  assert.equal('hiddenByReports' in docs.get('posts/p1'), false);

  // Set to never: nothing hidden.
  docs.set('config/moderation', { autoHideAt: 0 });
  delete docs.get('posts/p1').hiddenByReports;
  assert.equal(await autoHideReported(memoryStore(docs), later(40)), 0);
});

test('a scheduled announcement goes when its time comes, and not before', async () => {
  const docs = world();
  const calls = [];
  const send = async (by, body) => {
    calls.push([by, body.communityId ?? 'everyone', body.from, body.round]);
    return body.communityId && body.from === 0 ? { done: false, next: 10 } : { done: true };
  };
  const line = { title: 't', body: 'b' };
  docs.set('scheduled/s1', { bn: line, en: line, at: later(30), by: 'uOwner' });
  docs.set('scheduled/s2', { bn: line, en: line, at: later(10), by: 'uOwner', communityId: 'bulls1' });

  assert.equal(await sendScheduled(memoryStore(docs), send, later(5)), 0);
  // s2 is due: its first ten phones, its place kept.
  assert.equal(await sendScheduled(memoryStore(docs), send, later(15)), 1);
  assert.equal(docs.get('scheduled/s2').from, 10);
  // Then the rest, and it is done.
  await sendScheduled(memoryStore(docs), send, later(20));
  assert.equal(docs.has('scheduled/s2'), false);
  assert.equal(docs.has('scheduled/s1'), true, 'not yet');
  await sendScheduled(memoryStore(docs), send, later(35));
  assert.equal(docs.has('scheduled/s1'), false);
  assert.deepEqual(calls, [['uOwner', 'bulls1', 0, 10], ['uOwner', 'bulls1', 10, 10], ['uOwner', 'everyone', 0, 10]]);
});

test('one that cannot go is dropped; one that ran out of requests waits', async () => {
  const docs = world();
  const line = { title: 't', body: 'b' };
  docs.set('scheduled/s1', { bn: line, en: line, at: T0, by: 'uGone' });
  await sendScheduled(memoryStore(docs), async () => { throw new TryAgain('out of budget'); }, later(1));
  assert.ok(docs.has('scheduled/s1'));
  await sendScheduled(memoryStore(docs), async () => { throw new Error('not an admin'); }, later(1));
  assert.equal(docs.has('scheduled/s1'), false);
});

test('scheduling: a time ahead, within sixty days; and cancelling', async () => {
  const docs = world();
  const act = (body) => adminAction(memoryStore(docs), { auth: {}, push: async () => {} }, 'uOwner', body, T0);
  const msg = { bn: { title: 'খবর', body: 'আজ রাতে' }, en: { title: 'News', body: 'Tonight' } };
  const { id } = await act({ action: 'schedule', ...msg, at: later(60).toISOString() });
  assert.equal(docs.get(`scheduled/${id}`).at.getTime(), later(60).getTime());
  for (const at of [later(-1).toISOString(), later(61 * 24 * 60).toISOString(), 'soon', undefined]) {
    await assert.rejects(act({ action: 'schedule', ...msg, at }), (e) => e.status === 400, String(at));
  }
  await act({ action: 'cancelScheduled', id });
  assert.equal(docs.has(`scheduled/${id}`), false);
});

test('an admin turns their own report alerts off and on', async () => {
  const docs = world();
  const act = (body) => adminAction(memoryStore(docs), { auth: {}, push: async () => {} }, 'uQuiet', body, T0);
  await act({ action: 'alerts', on: true });
  assert.equal(docs.get('admins/uQuiet').alerts, true);
  await act({ action: 'alerts', on: false });
  assert.equal(docs.get('admins/uQuiet').alerts, false);
});
