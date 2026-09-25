// Pins the worker's formula to tool/stats_fixture.json — the same file the
// app's Dart implementation is tested against. If this fails and the Dart
// test passes, stats.js has drifted from the app.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import { leaderboardStats } from '../src/stats.js';

const fixture = JSON.parse(
  readFileSync(new URL('../../tool/stats_fixture.json', import.meta.url), 'utf8'),
);

for (const c of fixture.cases) {
  test(c.name, () => {
    const actual = leaderboardStats(c.trades, new Date(c.now));

    assert.ok(Object.keys(c.expected).length > 0, 'fixture has no expected values');
    for (const [key, want] of Object.entries(c.expected)) {
      assert.ok(
        Math.abs(actual[key] - want) < 1e-9,
        `${key}: worker says ${actual[key]}, app says ${want}`,
      );
    }
  });
}
