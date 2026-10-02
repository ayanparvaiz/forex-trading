import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/core/market_sessions.dart';

void main() {
  Set<MarketSession> openAt(DateTime utc) => {
    for (final s in MarketSession.values)
      if (s.isOpenAt(utc)) s,
  };

  test('a Friday afternoon in Dhaka: London and New York', () {
    // 18:00 in Dhaka; London on summer time, New York on daylight time.
    final t = DateTime.utc(2026, 10, 2, 12);
    expect(openAt(t), {MarketSession.london, MarketSession.newYork});
    expect(busiestHours(t), isTrue);
    expect(marketWeekend(t), isFalse);
  });

  test('a Tuesday morning in Dhaka: Sydney and Tokyo', () {
    final t = DateTime.utc(2026, 1, 13, 2); // 08:00 in Dhaka
    expect(openAt(t), {MarketSession.sydney, MarketSession.tokyo});
    expect(busiestHours(t), isFalse);
  });

  test('the clocks moving move the sessions', () {
    // 07:30 UTC: London opens at 07:00 UTC in summer, 08:00 in winter.
    expect(
      MarketSession.london.isOpenAt(DateTime.utc(2026, 3, 27, 7, 30)),
      isFalse,
    );
    expect(
      MarketSession.london.isOpenAt(DateTime.utc(2026, 3, 30, 7, 30)),
      isTrue,
    );
    // New York, on its own dates: 12:30 UTC is 07:30 before, 08:30 after.
    expect(
      MarketSession.newYork.isOpenAt(DateTime.utc(2026, 3, 6, 12, 30)),
      isFalse,
    );
    expect(
      MarketSession.newYork.isOpenAt(DateTime.utc(2026, 3, 9, 12, 30)),
      isTrue,
    );
    // Sydney's summer is the other half of the year.
    expect(MarketSession.sydney.utcOffset(DateTime.utc(2026, 1, 15)), 11);
    expect(MarketSession.sydney.utcOffset(DateTime.utc(2026, 7, 15)), 10);
  });

  test('the weekend: from New York closing on Friday to Sydney on Monday', () {
    final saturday = DateTime.utc(2026, 10, 3, 12);
    expect(openAt(saturday), isEmpty);
    expect(marketWeekend(saturday), isTrue);
    // Sunday 21:00 UTC is Monday 08:00 in Sydney, a week begun.
    final mondayInSydney = DateTime.utc(2026, 10, 4, 21);
    expect(openAt(mondayInSydney), {MarketSession.sydney});
    expect(marketWeekend(mondayInSydney), isFalse);
    // A weekday night between sessions is no weekend.
    expect(marketWeekend(DateTime.utc(2026, 10, 1, 21, 30)), isFalse);
  });

  test('how long until it opens, or closes', () {
    final t = DateTime.utc(2026, 10, 2, 12, 40);
    // London closes at 16:00 UTC; New York at 21:00 UTC.
    expect(
      MarketSession.london.changeIn(t),
      const Duration(hours: 3, minutes: 20),
    );
    expect(
      MarketSession.newYork.changeIn(t),
      const Duration(hours: 8, minutes: 20),
    );
    // Tokyo next opens on Monday, 09:00 there: Monday 00:00 UTC.
    expect(
      MarketSession.tokyo.changeIn(t),
      DateTime.utc(2026, 10, 5).difference(t),
    );
  });
}
