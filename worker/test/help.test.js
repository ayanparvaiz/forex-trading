import { test } from 'node:test';
import assert from 'node:assert/strict';

import { HelpError, passwordHelp } from '../src/help.js';
import { memoryStore } from './memory-store.js';

const NOW = new Date('2026-10-04T10:00:00Z');
const world = () => new Map(Object.entries({ 'usernames/ana': { uid: 'uAna' } }));

test('a request to get back in: one open per account, the same answer for anyone', async () => {
  const docs = world();
  const ask = (body) => passwordHelp(memoryStore(docs), body, NOW);
  assert.deepEqual(await ask({ username: '@Ana', contact: '01711-000000', note: 'Lost my password' }), { ok: true });
  assert.deepEqual(docs.get('helpRequests/pw_uAna'), {
    kind: 'password', uid: 'uAna', username: 'ana', contact: '01711-000000', note: 'Lost my password', createdAt: NOW, status: 'open',
  });
  // Again while open: nothing new.
  await ask({ username: 'ana', contact: 'someone-else@example.com' });
  assert.equal(docs.get('helpRequests/pw_uAna').contact, '01711-000000');
  // Dealt with, then asked again: a fresh request.
  docs.get('helpRequests/pw_uAna').status = 'done';
  docs.get('helpRequests/pw_uAna').handledBy = 'uAdmin';
  await ask({ username: 'ana', contact: 'fb.com/ana' });
  assert.equal(docs.get('helpRequests/pw_uAna').status, 'open');
  assert.equal('handledBy' in docs.get('helpRequests/pw_uAna'), false);
  // Nobody by that name: the same answer, nothing kept.
  assert.deepEqual(await ask({ username: 'nobody', contact: 'abc' }), { ok: true });
  assert.equal([...docs.keys()].filter((k) => k.startsWith('helpRequests/')).length, 1);
});

test('a request has to make sense', async () => {
  for (const body of [{}, { username: 'ana' }, { username: 'ana', contact: 'x' }, { username: 'a b', contact: 'abc' }, { username: 'ana', contact: 'abc', note: 'x'.repeat(301) }]) {
    await assert.rejects(passwordHelp(memoryStore(world()), body, NOW), HelpError, JSON.stringify(body));
  }
});
