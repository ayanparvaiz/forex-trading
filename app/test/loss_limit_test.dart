import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/loss_limit.dart';
import 'package:forex_trading/models/trade.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late SharedPreferences prefs;

  Future<LossLimit> fresh() async {
    final l = LossLimit(prefs: prefs, clock: () => now);
    await l.load();
    return l;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 2, 15);
  });

  test('stricter counts at once; looser, or none, from midnight', () async {
    final limit = await fresh();
    expect(limit.percent, 0);

    await limit.set(5);
    expect(limit.percent, 5, reason: 'from none to any is stricter');
    await limit.set(2);
    expect(limit.percent, 2);

    await limit.set(5);
    expect(limit.percent, 2, reason: 'looser waits');
    expect(limit.pending, 5);
    await limit.set(0);
    expect(limit.percent, 2);
    expect(limit.pending, 0);

    // Remembered, waiting and all.
    expect((await fresh()).pending, 0);

    now = DateTime(2026, 10, 3, 0, 1);
    expect(limit.percent, 0);
    expect(limit.pending, isNull);
  });

  test(
    'changing your mind back to today’s limit drops what was waiting',
    () async {
      final limit = await fresh();
      await limit.set(3);
      await limit.set(5);
      expect(limit.pending, 5);
      await limit.set(3);
      expect(limit.pending, isNull);
      expect(limit.percent, 3);
    },
  );

  Trade closed(double exit) => Trade(
    id: 't$exit',
    symbol: 'EUR/USD',
    direction: TradeDirection.buy,
    lots: 1,
    entryPrice: 1.14,
    stopPrice: 1.138,
    targetPrice: 1.144,
    openedAt: DateTime(2026, 10, 2, 9),
    closedAt: DateTime(2026, 10, 2, 10),
    exitPrice: exit,
    exitReason: ExitReason.manual,
    balanceAtEntry: 10000,
    reason: 'a test trade with a reason',
  );

  test("today's loss, as a share of the day's points", () {
    // 20 pips on a lot, plus the spread: a little over 200 of 10,000.
    final loss = lossTodayPercent([closed(1.138)], 10000);
    expect(loss, greaterThan(2));
    expect(loss, lessThan(2.2));
    expect(lossTodayPercent([closed(1.144)], 10000), 0);
    expect(lossTodayPercent(const [], 10000), 0);
  });
}
