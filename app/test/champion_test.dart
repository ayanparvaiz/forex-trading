import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/models/community.dart';

void main() {
  test('month ids read as months; anything else does not', () {
    expect(monthOf('2026-09'), DateTime(2026, 9));
    expect(monthOf('2026-13'), isNull);
    expect(monthOf('Sept'), isNull);
  });

  test('the month crowned last is the one before, in Dhaka', () {
    expect(lastMonthId(DateTime.utc(2026, 10, 2, 12)), '2026-09');
    // 31 October 19:00 UTC is already November in Dhaka.
    expect(lastMonthId(DateTime.utc(2026, 10, 31, 19)), '2026-10');
    expect(lastMonthId(DateTime.utc(2027, 1, 5)), '2026-12');
  });
}
