// Fills in the `expected` block of tool/stats_fixture.json from the Dart
// implementation, which is the reference.
//
//   cd app && dart run tool/update_stats_fixture.dart
//
// Run it after changing a formula on purpose, then run both test suites. The
// worker's test will fail until stats.js is changed to match — which is the
// whole point: the two cannot drift without somebody noticing.

import 'dart:convert';
import 'dart:io';

import 'package:forex_trading/core/leaderboard_stats.dart';
import 'package:forex_trading/models/trade.dart';

void main() {
  final file = File('../tool/stats_fixture.json');
  final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  for (final raw in fixture['cases'] as List) {
    final c = raw as Map<String, dynamic>;
    final trades = [
      for (final t in c['trades'] as List)
        Trade.fromJson(
          (t as Map)['id'] as String,
          t.cast<String, Object?>(),
        ),
    ];

    final stats = LeaderboardStats.from(
      trades,
      now: DateTime.parse(c['now'] as String),
    );
    c['expected'] = stats.toJson();
    stdout.writeln('${c['name']}: ${stats.toJson()}');
  }

  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(fixture)}\n',
  );
}
