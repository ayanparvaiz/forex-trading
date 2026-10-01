import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/models/achievement.dart';

void main() {
  test('the app draws exactly what the worker awards, in its order', () {
    // worker/src/achievements.js decides who has earned what; a name here
    // that the worker never writes would never light up, and one the worker
    // writes that is missing here would never show.
    final worker = File('../worker/src/achievements.js').readAsStringSync();
    final list = RegExp(
      r'export const ACHIEVEMENTS = \[(.*?)\];',
      dotAll: true,
    ).firstMatch(worker)!.group(1)!;
    final ids = RegExp(r"'([a-z0-9_]+)'").allMatches(list).map((m) => m[1]);
    expect([for (final a in Achievement.all) a.id], ids.toList());
  });

  test('earned ones in order, unknown ids left out', () {
    final got = Achievement.of(['streak_7', 'someday_new', 'first_trade']);
    expect([for (final a in got) a.id], ['first_trade', 'streak_7']);
  });
}
