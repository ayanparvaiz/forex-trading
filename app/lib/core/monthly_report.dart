import '../models/trade.dart';
import 'calculations.dart';

/// One month of trading, as a report card: what was done, how well the
/// rules were kept, and the one thing to fix next month.
class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.trades,
    required this.wins,
    required this.totalR,
    required this.discipline,
    required this.journaled,
    required this.daysTraded,
    required this.worstRule,
    required this.worstRuleCount,
    required this.bestR,
  });

  /// The first day of the month reported on.
  final DateTime month;
  final int trades;
  final int wins;
  final double totalR;

  /// 0–100, over this month's trades alone.
  final double discipline;

  /// Trades with a lesson written.
  final int journaled;
  final int daysTraded;

  /// The rule broken worst this month — most often, weighted by what it
  /// costs — or null for a clean month.
  final RuleViolation? worstRule;
  final int worstRuleCount;

  /// The best single result, in R; null with no trades.
  final double? bestR;

  double get winRate => trades == 0 ? 0 : wins / trades;

  bool get isEmpty => trades == 0;

  /// The report for the month [month] falls in, from every closed trade.
  factory MonthlyReport.of(List<Trade> all, DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final closed = [
      for (final t in all)
        if (!t.isOpen &&
            !t.closedAt!.isBefore(start) &&
            t.closedAt!.isBefore(end))
          t,
    ];
    final breakdown = calculateDiscipline(closed);
    final worst = breakdown.worstFirst.firstOrNull;
    final rs = [for (final t in closed) t.rMultiple ?? 0];
    return MonthlyReport(
      month: start,
      trades: closed.length,
      wins: rs.where((r) => r > 0).length,
      totalR: rs.fold(0, (a, b) => a + b),
      discipline: breakdown.score,
      journaled: closed.where((t) => (t.lesson ?? '').trim().isNotEmpty).length,
      daysTraded: {
        for (final t in closed)
          DateTime(t.closedAt!.year, t.closedAt!.month, t.closedAt!.day),
      }.length,
      worstRule: worst?.key,
      worstRuleCount: worst?.value ?? 0,
      bestR: rs.isEmpty ? null : rs.reduce((a, b) => a > b ? a : b),
    );
  }
}
