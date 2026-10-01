import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/core/week.dart';

void main() {
  test('the same weeks the worker names', () {
    // Mirrors worker/test/weekly.test.js.
    expect(weekId(DateTime.utc(2026, 10, 1, 6)), '2026-W40');
    expect(weekId(DateTime.utc(2026, 10, 4, 17, 59)), '2026-W40');
    expect(weekId(DateTime.utc(2026, 10, 4, 18, 1)), '2026-W41');
    expect(weekId(DateTime.utc(2027, 1, 1, 6)), '2026-W53');
    expect(weekId(DateTime.utc(2025, 12, 31, 6)), '2026-W01');
  });
}
