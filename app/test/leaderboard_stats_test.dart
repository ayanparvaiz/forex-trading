import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/core/leaderboard_stats.dart';
import 'package:forex_trading/models/trade.dart';

/// Pins the leaderboard formula to tool/stats_fixture.json.
///
/// The worker computes these same numbers in JavaScript and is tested against
/// the same file, so the two implementations can only disagree by one of these
/// two tests failing. If this one fails after a deliberate formula change, run
/// `dart run tool/update_stats_fixture.dart` and then fix stats.js until the
/// worker's test passes too.
void main() {
  final fixture =
      jsonDecode(File('../tool/stats_fixture.json').readAsStringSync())
          as Map<String, dynamic>;

  for (final raw in fixture['cases'] as List) {
    final c = raw as Map<String, dynamic>;

    test(c['name'] as String, () {
      final trades = [
        for (final t in c['trades'] as List)
          Trade.fromJson((t as Map)['id'] as String, t.cast<String, Object?>()),
      ];

      final actual = LeaderboardStats.from(
        trades,
        now: DateTime.parse(c['now'] as String),
      ).toJson();
      final expected = (c['expected'] as Map).cast<String, Object?>();

      expect(expected, isNotEmpty, reason: 'fixture has no expected values');
      for (final key in expected.keys) {
        final want = expected[key]! as num;
        final got = actual[key]! as num;
        expect(got, closeTo(want, 1e-9), reason: key);
      }
    });
  }
}
