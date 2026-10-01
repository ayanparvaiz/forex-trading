import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/core/monthly_report.dart';
import 'package:forex_trading/models/trade.dart';

/// A closed EUR/USD buy, 20 pips risked, that ended at [r] R on [day].
Trade trade(
  int month,
  int day, {
  double r = 1,
  Set<RuleViolation> violations = const {},
  String? lesson = 'kept the plan',
}) {
  const entry = 1.1;
  return Trade(
    id: 't$month-$day-$r',
    symbol: 'EUR/USD',
    direction: TradeDirection.buy,
    lots: 0.1,
    entryPrice: entry,
    stopPrice: entry - 0.002,
    targetPrice: entry + 0.004,
    openedAt: DateTime(2026, month, day, 10),
    balanceAtEntry: 10000,
    reason: 'retest of the daily level',
    closedAt: DateTime(2026, month, day, 12),
    // Spread costs 0.8 of the 20 pips risked; aim past it.
    exitPrice: entry + (r * 20 + 0.8) * 0.0001,
    violations: violations,
    lesson: lesson,
  );
}

void main() {
  test("a month's trades, and only that month's", () {
    final report = MonthlyReport.of([
      trade(8, 31, r: 5),
      trade(9, 2, r: 2),
      trade(9, 2, r: -1, violations: {RuleViolation.movedStop}),
      trade(9, 15, r: 1, lesson: null),
      trade(10, 1, r: 3),
    ], DateTime(2026, 9, 20));

    expect(report.month, DateTime(2026, 9));
    expect(report.trades, 3);
    expect(report.wins, 2);
    expect(report.daysTraded, 2);
    expect(report.journaled, 2);
    expect(report.totalR, closeTo(2, 0.05));
    expect(report.bestR, closeTo(2, 0.05));
    expect(report.worstRule, RuleViolation.movedStop);
    expect(report.worstRuleCount, 1);
    // One trade lost 35 of its 100.
    expect(report.discipline, closeTo((100 + 65 + 100) / 3, 0.01));
  });

  test('a clean month has no rule to fix; an empty one says so', () {
    final clean = MonthlyReport.of([trade(9, 3)], DateTime(2026, 9));
    expect(clean.worstRule, isNull);
    expect(MonthlyReport.of(const [], DateTime(2026, 9)).isEmpty, isTrue);
  });
}
