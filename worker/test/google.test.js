// Deleting an account trusts auth_time, so the one check on it is pinned.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { signedInRecently } from '../src/google.js';

const now = Date.parse('2026-09-25T10:00:00Z');
const secondsAgo = (s) => Math.floor(now / 1000) - s;

test('a password typed a minute ago is recent', () => {
  assert.equal(signedInRecently({ auth_time: secondsAgo(60) }, 300, now), true);
});

test('a session restored hours after sign-in is not', () => {
  assert.equal(signedInRecently({ auth_time: secondsAgo(3 * 3600) }, 300, now), false);
});

test('a token with no auth_time is not', () => {
  assert.equal(signedInRecently({}, 300, now), false);
  assert.equal(signedInRecently({ auth_time: String(secondsAgo(10)) }, 300, now), false);
});

test('a clock a little ahead is tolerated, one far ahead is not', () => {
  assert.equal(signedInRecently({ auth_time: secondsAgo(-30) }, 300, now), true);
  assert.equal(signedInRecently({ auth_time: secondsAgo(-3600) }, 300, now), false);
});
