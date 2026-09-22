import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/core/calculations.dart';
import 'package:forex_trading/models/instrument.dart';
import 'package:forex_trading/models/trade.dart';

/// Builds a EUR/USD long: 20 pip stop, 40 pip target, closed at [exitPrice].
Trade _trade({
  required double lots,
  required double exitPrice,
  double balance = 1000,
  Set<RuleViolation> violations = const {},
  DateTime? openedAt,
}) {
  final opened = openedAt ?? DateTime(2026, 9, 1, 10);
  return Trade(
    id: 't',
    symbol: 'EUR/USD',
    direction: TradeDirection.buy,
    lots: lots,
    entryPrice: 1.08500,
    stopPrice: 1.08300,
    targetPrice: 1.08900,
    openedAt: opened,
    closedAt: opened.add(const Duration(hours: 2)),
    exitPrice: exitPrice,
    balanceAtEntry: balance,
    reason: 'Support bounce, H1 structure holding',
    violations: violations,
  );
}

void main() {
  group('sizePosition', () {
    test('sizes from risk, not from a lot size the trader picked', () {
      final size = sizePosition(
        balance: 1000,
        riskPercent: 1,
        entryPrice: 1.08500,
        stopPrice: 1.08300,
        instrument: Instrument.eurusd,
      );

      expect(size.stopPips, closeTo(20, 0.001));
      // $10 risk / (20 pips x $10 per pip per lot) = 0.05 lots
      expect(size.lots, closeTo(0.05, 1e-9));
      expect(size.actualRisk, closeTo(10, 0.01));
      expect(size.isBelowMinimum, isFalse);
    });

    test('rounds down so the risk rule is never broken by rounding', () {
      final size = sizePosition(
        balance: 1000,
        riskPercent: 1.3, // $13 -> 0.065 lots exactly
        entryPrice: 1.08500,
        stopPrice: 1.08300,
        instrument: Instrument.eurusd,
      );

      expect(size.exactLots, closeTo(0.065, 1e-9));
      expect(size.lots, closeTo(0.06, 1e-9)); // down, not up to 0.07
      expect(size.actualRisk, lessThanOrEqualTo(size.plannedRisk));
    });

    test('flags that a \$100 account cannot risk 1% on a 20 pip stop', () {
      final size = sizePosition(
        balance: 100,
        riskPercent: 1,
        entryPrice: 1.08500,
        stopPrice: 1.08300,
        instrument: Instrument.eurusd,
      );

      expect(size.isBelowMinimum, isTrue);
      expect(size.lots, 0);
      // One micro lot would risk $2 — 2% of a $100 account.
      expect(size.minimumLotRiskPercent, closeTo(2.0, 0.001));
    });

    test('uses the right pip size for JPY pairs', () {
      final size = sizePosition(
        balance: 1000,
        riskPercent: 1,
        entryPrice: 150.500,
        stopPrice: 150.300, // 20 pips at 0.01 per pip
        instrument: Instrument.usdjpy,
      );

      expect(size.stopPips, closeTo(20, 0.001));
      // $10 / (20 x $6.70) = 0.0746 -> rounds down to 0.07
      expect(size.lots, closeTo(0.07, 1e-9));
    });
  });

  group('Trade maths', () {
    test('risk, reward and R:R come from price distances', () {
      final t = _trade(lots: 0.05, exitPrice: 1.08900);

      expect(t.riskPips, closeTo(20, 0.001));
      expect(t.rewardPips, closeTo(40, 0.001));
      expect(t.riskReward, closeTo(2.0, 0.001));
      expect(t.riskAmount, closeTo(10, 0.01));
      expect(t.riskPercent, closeTo(1.0, 0.01));
    });

    test('a 2R winner nets less than 2R once the spread is paid', () {
      final t = _trade(lots: 0.05, exitPrice: 1.08900);

      expect(t.spreadCost, closeTo(0.4, 0.001)); // 0.8 pips x $10 x 0.05
      expect(t.realisedPnl, closeTo(19.6, 0.01)); // $20 gross - $0.40
      expect(t.rMultiple, closeTo(1.96, 0.01));
    });

    test('a stopped-out trade loses slightly more than 1R', () {
      final t = _trade(lots: 0.05, exitPrice: 1.08300);

      expect(t.realisedPnl, closeTo(-10.4, 0.01));
      expect(t.rMultiple, closeTo(-1.04, 0.01));
    });

    test('break-even sits beyond entry by the spread', () {
      final t = _trade(lots: 0.05, exitPrice: 1.08900);

      expect(t.breakEvenPrice, greaterThan(t.entryPrice));
      expect(t.netPnlAt(t.breakEvenPrice), closeTo(0, 0.001));
    });

    test('holding overnight charges swap', () {
      final opened = DateTime(2026, 9, 1, 10);
      final t = Trade(
        id: 't',
        symbol: 'EUR/USD',
        direction: TradeDirection.buy,
        lots: 1,
        entryPrice: 1.08500,
        stopPrice: 1.08300,
        targetPrice: 1.08900,
        openedAt: opened,
        closedAt: opened.add(const Duration(days: 3)),
        exitPrice: 1.08500,
        balanceAtEntry: 10000,
        reason: 'carry test',
      );

      // 3 nights x -$7.20 per lot, plus the spread, all against the trader.
      expect(t.swapCost, closeTo(-21.6, 0.01));
      expect(t.realisedPnl, closeTo(-29.6, 0.01));
    });
  });

  group('TradeStats', () {
    test('expectancy is average R, and survives a losing win-rate', () {
      final trades = [
        _trade(lots: 0.05, exitPrice: 1.08900), // +1.96R
        _trade(lots: 0.05, exitPrice: 1.08300), // -1.04R
        _trade(lots: 0.05, exitPrice: 1.08300), // -1.04R
      ];

      final stats = TradeStats.from(trades, startingBalance: 1000);

      expect(stats.total, 3);
      expect(stats.wins, 1);
      expect(stats.winRate, closeTo(1 / 3, 0.001));
      // Loses 2 of 3 and still makes money — the point of the whole app.
      expect(stats.expectancyR, closeTo((1.96 - 1.04 - 1.04) / 3, 0.01));
      expect(stats.netPnl, closeTo(19.6 - 10.4 - 10.4, 0.01));
    });

    test('tracks peak-to-trough drawdown and the gain needed to recover', () {
      final trades = [
        _trade(lots: 0.5, exitPrice: 1.08900), // +$196
        _trade(lots: 0.5, exitPrice: 1.08300), // -$104
        _trade(lots: 0.5, exitPrice: 1.08300), // -$104
      ];

      final stats = TradeStats.from(trades, startingBalance: 1000);

      // Peak 1196, trough 988 -> 17.39% drawdown.
      expect(stats.maxDrawdownPercent, closeTo(17.39, 0.05));
      expect(
        stats.recoveryNeededPercent,
        closeTo(recoveryGainFor(stats.maxDrawdownPercent), 0.01),
      );
      expect(stats.equityCurve.first, 1000);
      expect(stats.equityCurve.length, 4);
    });

    test('empty history is not a divide by zero', () {
      expect(TradeStats.from([], startingBalance: 100).total, 0);
    });
  });

  test('recoveryGainFor shows why big losses are near-fatal', () {
    expect(recoveryGainFor(10), closeTo(11.11, 0.01));
    expect(recoveryGainFor(50), closeTo(100, 0.01));
    expect(recoveryGainFor(90), closeTo(900, 0.01));
  });

  group('discipline', () {
    test('a clean trade scores 100 even when it loses money', () {
      final loser = _trade(lots: 0.05, exitPrice: 1.08300);

      expect(loser.realisedPnl, lessThan(0));
      expect(calculateDiscipline([loser]).score, 100);
    });

    test('a profitable trade that broke rules scores badly', () {
      final winner = _trade(
        lots: 0.05,
        exitPrice: 1.08900,
        violations: {RuleViolation.movedStop, RuleViolation.riskTooHigh},
      );

      final d = calculateDiscipline([winner]);
      expect(winner.realisedPnl, greaterThan(0));
      expect(d.score, 100 - 35 - 30);
      expect(d.worstFirst.first.key, RuleViolation.movedStop);
    });

    test('penalties cannot push a trade below zero', () {
      final awful = _trade(
        lots: 0.05,
        exitPrice: 1.08300,
        violations: RuleViolation.values.toSet(),
      );

      expect(calculateDiscipline([awful]).score, 0);
    });
  });

  group('detectEntryViolations', () {
    final now = DateTime(2026, 9, 22, 14);

    test('passes a well-planned trade', () {
      final v = detectEntryViolations(
        riskPercent: 1.0,
        riskReward: 2.0,
        reason: 'Daily support retest with bullish engulfing',
        recentTrades: const [],
        now: now,
      );
      expect(v, isEmpty);
    });

    test('catches oversized risk, thin reward and a missing reason', () {
      final v = detectEntryViolations(
        riskPercent: 5,
        riskReward: 0.8,
        reason: 'idk',
        recentTrades: const [],
        now: now,
      );
      expect(
        v,
        containsAll([
          RuleViolation.riskTooHigh,
          RuleViolation.poorRiskReward,
          RuleViolation.noReason,
        ]),
      );
    });

    test('does not punish a 1.05% size caused by lot rounding', () {
      final v = detectEntryViolations(
        riskPercent: 1.05,
        riskReward: 2,
        reason: 'Support bounce on the H1 chart',
        recentTrades: const [],
        now: now,
      );
      expect(v, isEmpty);
    });

    test('flags re-entering minutes after a loss', () {
      final justLost = _trade(
        lots: 0.05,
        exitPrice: 1.08300,
        openedAt: now.subtract(const Duration(hours: 2, minutes: 5)),
      );

      final v = detectEntryViolations(
        riskPercent: 1,
        riskReward: 2,
        reason: 'It has to bounce from here, it fell too far',
        recentTrades: [justLost],
        now: now,
      );
      expect(v, contains(RuleViolation.revengeTrade));
    });

    test('flags the fourth trade of the day', () {
      final today = List.generate(
        3,
        (i) => _trade(
          lots: 0.05,
          exitPrice: 1.08900,
          openedAt: DateTime(2026, 9, 22, 9 + i),
        ),
      );

      final v = detectEntryViolations(
        riskPercent: 1,
        riskReward: 2,
        reason: 'Another clean setup on the 15 minute chart',
        recentTrades: today,
        now: now,
      );
      expect(v, contains(RuleViolation.overtrading));
    });
  });
}
