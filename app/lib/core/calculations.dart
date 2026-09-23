import 'dart:math' as math;

import '../models/instrument.dart';
import '../models/trade.dart';

/// Result of sizing a position for a fixed money risk.
///
/// The interesting field is [isBelowMinimum]. On a $100 account a 1% risk with
/// a sane stop often works out smaller than one micro lot — the smallest thing
/// a real broker will accept. Most simulators quietly round up and teach the
/// trader a lie. This one surfaces it.
class PositionSize {
  const PositionSize({
    required this.exactLots,
    required this.lots,
    required this.plannedRisk,
    required this.actualRisk,
    required this.actualRiskPercent,
    required this.stopPips,
    required this.isBelowMinimum,
    required this.minimumLotRiskPercent,
  });

  /// Size that would risk exactly the planned amount — usually not tradable.
  final double exactLots;

  /// Size after rounding down to the broker's 0.01 lot step.
  final double lots;

  /// Money the trader intended to risk.
  final double plannedRisk;

  /// Money actually at risk once the size is rounded.
  final double actualRisk;
  final double actualRiskPercent;

  final double stopPips;

  /// True when even one micro lot risks more than planned.
  final bool isBelowMinimum;

  /// What a single micro lot would actually cost, as a percentage of balance.
  final double minimumLotRiskPercent;

  bool get isTradable => lots >= Instrument.minLot;
}

/// Position sizing — risk first, size second.
///
/// The trader picks how much they are willing to lose; the lot size falls out
/// of that and the stop distance. Never the other way round.
PositionSize sizePosition({
  required double balance,
  required double riskPercent,
  required double entryPrice,
  required double stopPrice,
  required Instrument instrument,
}) {
  final stopPips = instrument.pipsBetween(entryPrice, stopPrice);
  final plannedRisk = balance * riskPercent / 100;
  final riskPerLot = stopPips * instrument.pipValuePerLot;

  if (stopPips <= 0 || riskPerLot <= 0) {
    return PositionSize(
      exactLots: 0,
      lots: 0,
      plannedRisk: plannedRisk,
      actualRisk: 0,
      actualRiskPercent: 0,
      stopPips: stopPips,
      isBelowMinimum: false,
      minimumLotRiskPercent: 0,
    );
  }

  final exactLots = plannedRisk / riskPerLot;

  // Round down, never up: rounding up would quietly break the risk rule the
  // trader just set.
  //
  // The epsilon matters. In binary floating point 0.05 / 0.01 is 4.999999…, so
  // a bare floor() would turn an exactly-sized 0.05 position into 0.04 and
  // under-risk every clean number the trader enters.
  const epsilon = 1e-9;
  final steps = (exactLots / Instrument.minLot + epsilon).floor();
  final lots = double.parse((steps * Instrument.minLot).toStringAsFixed(2));

  final minimumLotRisk = Instrument.minLot * riskPerLot;
  final actualRisk = lots * riskPerLot;

  return PositionSize(
    exactLots: exactLots,
    lots: lots,
    plannedRisk: plannedRisk,
    actualRisk: actualRisk,
    actualRiskPercent: balance == 0 ? 0 : actualRisk / balance * 100,
    stopPips: stopPips,
    isBelowMinimum: exactLots < Instrument.minLot,
    minimumLotRiskPercent: balance == 0 ? 0 : minimumLotRisk / balance * 100,
  );
}

/// Aggregate performance over a set of closed trades.
///
/// Every figure is in R where possible. Dollars flatter a trader who sized up
/// on one lucky trade; R does not.
class TradeStats {
  const TradeStats({
    required this.total,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.avgWinR,
    required this.avgLossR,
    required this.expectancyR,
    required this.profitFactor,
    required this.totalR,
    required this.netPnl,
    required this.maxDrawdownPercent,
    required this.recoveryNeededPercent,
    required this.equityCurve,
  });

  final int total;
  final int wins;
  final int losses;

  /// Fraction, 0..1.
  final double winRate;

  /// Average winner and loser, in R. [avgLossR] is positive magnitude.
  final double avgWinR;
  final double avgLossR;

  /// Average R per trade. Positive means the strategy makes money over time —
  /// this single number matters more than win rate.
  final double expectancyR;

  /// Gross profit divided by gross loss. Above 1.0 is profitable.
  final double profitFactor;

  final double totalR;
  final double netPnl;

  /// Largest peak-to-trough fall of the equity curve, as a percentage.
  final double maxDrawdownPercent;

  /// Gain required to climb back out of [maxDrawdownPercent].
  ///
  /// This is the number that stops people risking 20% a trade: lose 50% and you
  /// need 100% just to get level.
  final double recoveryNeededPercent;

  /// Balance after each closed trade, starting with the opening balance.
  final List<double> equityCurve;

  static const empty = TradeStats(
    total: 0,
    wins: 0,
    losses: 0,
    winRate: 0,
    avgWinR: 0,
    avgLossR: 0,
    expectancyR: 0,
    profitFactor: 0,
    totalR: 0,
    netPnl: 0,
    maxDrawdownPercent: 0,
    recoveryNeededPercent: 0,
    equityCurve: [],
  );

  factory TradeStats.from(
    List<Trade> trades, {
    required double startingBalance,
  }) {
    final closed = trades.where((t) => !t.isOpen).toList()
      ..sort((a, b) => a.closedAt!.compareTo(b.closedAt!));

    if (closed.isEmpty) {
      return TradeStats.empty;
    }

    final rs = <double>[];
    var grossProfit = 0.0;
    var grossLoss = 0.0;
    var netPnl = 0.0;

    var equity = startingBalance;
    var peak = startingBalance;
    var maxDd = 0.0;
    final curve = <double>[startingBalance];

    for (final t in closed) {
      final pnl = t.realisedPnl ?? 0;
      final r = t.rMultiple ?? 0;

      rs.add(r);
      netPnl += pnl;
      if (pnl >= 0) {
        grossProfit += pnl;
      } else {
        grossLoss += -pnl;
      }

      equity += pnl;
      curve.add(equity);
      if (equity > peak) peak = equity;
      if (peak > 0) {
        final dd = (peak - equity) / peak;
        if (dd > maxDd) maxDd = dd;
      }
    }

    final winR = rs.where((r) => r > 0).toList();
    final lossR = rs.where((r) => r <= 0).toList();

    final avgWin = winR.isEmpty
        ? 0.0
        : winR.reduce((a, b) => a + b) / winR.length;
    final avgLoss = lossR.isEmpty
        ? 0.0
        : -(lossR.reduce((a, b) => a + b) / lossR.length);

    final totalR = rs.reduce((a, b) => a + b);

    return TradeStats(
      total: closed.length,
      wins: winR.length,
      losses: lossR.length,
      winRate: winR.length / closed.length,
      avgWinR: avgWin,
      avgLossR: avgLoss,
      expectancyR: totalR / closed.length,
      profitFactor: grossLoss == 0
          ? (grossProfit > 0 ? double.infinity : 0)
          : grossProfit / grossLoss,
      totalR: totalR,
      netPnl: netPnl,
      maxDrawdownPercent: maxDd * 100,
      recoveryNeededPercent: maxDd >= 1
          ? double.infinity
          : maxDd / (1 - maxDd) * 100,
      equityCurve: curve,
    );
  }
}

/// Gain needed to recover from a given loss, as a percentage.
///
/// Lose 10% → need 11.1%. Lose 50% → need 100%. Lose 90% → need 900%.
double recoveryGainFor(double lossPercent) {
  final loss = lossPercent / 100;
  if (loss >= 1) return double.infinity;
  return loss / (1 - loss) * 100;
}

/// How the discipline score broke down, rule by rule.
class DisciplineBreakdown {
  const DisciplineBreakdown({
    required this.score,
    required this.tradesScored,
    required this.violationCounts,
  });

  /// 0–100. This is what the leaderboard ranks on.
  final double score;
  final int tradesScored;

  /// How many trades broke each rule.
  final Map<RuleViolation, int> violationCounts;

  /// Rules broken at least once, worst offender first.
  List<MapEntry<RuleViolation, int>> get worstFirst {
    final entries = violationCounts.entries.where((e) => e.value > 0).toList()
      ..sort(
        (a, b) => (b.value * b.key.weight).compareTo(a.value * a.key.weight),
      );
    return entries;
  }
}

/// Discipline score — the app's headline metric.
///
/// Deliberately ignores profit. A trader who followed every rule and still lost
/// scores 100; one who broke every rule and got lucky scores near zero. Ranking
/// people by profit instead would just be a casino with fake money.
DisciplineBreakdown calculateDiscipline(List<Trade> trades) {
  final closed = trades.where((t) => !t.isOpen).toList();
  final counts = {for (final v in RuleViolation.values) v: 0};

  if (closed.isEmpty) {
    return DisciplineBreakdown(
      score: 100,
      tradesScored: 0,
      violationCounts: counts,
    );
  }

  var totalScore = 0.0;
  for (final trade in closed) {
    var penalty = 0;
    for (final v in trade.violations) {
      penalty += v.weight;
      counts[v] = counts[v]! + 1;
    }
    totalScore += math.max(0, 100 - penalty);
  }

  return DisciplineBreakdown(
    score: totalScore / closed.length,
    tradesScored: closed.length,
    violationCounts: counts,
  );
}

/// Rules checked the moment an order is placed.
///
/// [maxRiskPercent] and [minRiskReward] are the trader's own plan; breaking
/// your own plan is the violation, not picking a particular number.
Set<RuleViolation> detectEntryViolations({
  required double riskPercent,
  required double riskReward,
  required String reason,
  required List<Trade> recentTrades,
  required DateTime now,
  double maxRiskPercent = 1.0,
  double minRiskReward = 1.5,
  int maxTradesPerDay = 3,
}) {
  final violations = <RuleViolation>{};

  // A small tolerance, so a 1.02% size from lot rounding is not a "violation".
  if (riskPercent > maxRiskPercent * 1.1) {
    violations.add(RuleViolation.riskTooHigh);
  }
  if (reason.trim().length < 10) {
    violations.add(RuleViolation.noReason);
  }
  if (riskReward < minRiskReward) {
    violations.add(RuleViolation.poorRiskReward);
  }

  final lastLoss = recentTrades
      .where((t) => !t.isOpen && (t.realisedPnl ?? 0) < 0)
      .fold<DateTime?>(null, (latest, t) {
        final closedAt = t.closedAt!;
        if (latest == null || closedAt.isAfter(latest)) return closedAt;
        return latest;
      });
  if (lastLoss != null &&
      now.difference(lastLoss) < const Duration(minutes: 15)) {
    violations.add(RuleViolation.revengeTrade);
  }

  final todayCount = recentTrades.where((t) {
    final d = t.openedAt;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }).length;
  if (todayCount >= maxTradesPerDay) {
    violations.add(RuleViolation.overtrading);
  }

  return violations;
}
