// The practice market's starting prices, from the ECB's dollar rates.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { pairsFromUsdRates, referenceRates } from '../src/rates.js';

test('dollar rates become the app\'s pairs', () => {
  assert.deepEqual(pairsFromUsdRates({ EUR: 0.87696, GBP: 0.75458, JPY: 157.59 }), {
    'EUR/USD': 1.1403,
    'GBP/USD': 1.32524,
    'USD/JPY': 157.59,
  });
});

test('a missing or absurd rate is left out, not guessed', () => {
  assert.deepEqual(pairsFromUsdRates({ EUR: 0.9, GBP: 0, JPY: 5 }), { 'EUR/USD': 1.11111 });
  assert.deepEqual(pairsFromUsdRates(undefined), {});
});

test('a feed with nothing usable is an error', async () => {
  const fake = async () => new Response(JSON.stringify({ date: '2026-09-25', rates: {} }));
  await assert.rejects(referenceRates(fake));
  const down = async () => new Response('no', { status: 503 });
  await assert.rejects(referenceRates(down));
});

test('a good feed says when the rates are from', async () => {
  const fake = async () => new Response(JSON.stringify({ date: '2026-09-25', rates: { EUR: 0.87696, GBP: 0.75458, JPY: 157.59 } }));
  const r = await referenceRates(fake);
  assert.equal(r.date, '2026-09-25');
  assert.equal(r.pairs['USD/JPY'], 157.59);
});
