import '../models/trade.dart';
import 'calculations.dart';

/// The six numbers a leaderboard row shows, derived from a trade log.
///
/// This exists twice: here, and in `worker/src/stats.js`, which is what
/// actually writes these fields to Firestore. Two implementations of one
/// formula is how numbers drift apart without anyone noticing, so both are
/// tested against the same file — `tool/stats_fixture.json` — and a change to
/// either that the other does not match fails a test.
///
/// Every field is derived from closed trades only. An open position has no
/// result yet, and a score that moved with the live price would reward whoever
/// checked the leaderboard at the right moment.
class LeaderboardStats {
  const LeaderboardStats({
    required this.disciplineScore,
    required this.badgePoints,
    required this.tradeCount,
    required this.totalR,
    required this.winRate,
    required this.journalStreak,
  });

  final double disciplineScore;

  /// Net wins across every day played. Can go negative; the badge ladder
  /// floors it at zero for display, but the stored number is the honest one.
  final int badgePoints;

  final int tradeCount;
  final double totalR;

  /// Fraction, 0..1.
  final double winRate;

  /// Consecutive days, ending today or yesterday, with at least one closed
  /// trade that has a lesson written on it.
  final int journalStreak;

  /// Days are counted in Bangladesh time, not the device's zone and not UTC.
  ///
  /// The app and the server have to agree on where midnight is, or a streak
  /// could be three on the phone and two on the leaderboard. Dhaka is fixed at
  /// UTC+6 with no daylight saving, so it is the same answer everywhere.
  static const _dayOffset = Duration(hours: 6);

  static int _dayOf(DateTime t) =>
      t.toUtc().add(_dayOffset).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  factory LeaderboardStats.from(List<Trade> trades, {required DateTime now}) {
    final closed = trades.where((t) => !t.isOpen).toList();
    final stats = TradeStats.from(closed, startingBalance: 0);

    var badge = 0;
    for (final t in closed) {
      badge += (t.realisedPnl ?? 0) > 0 ? 1 : -1;
    }

    return LeaderboardStats(
      disciplineScore: calculateDiscipline(closed).score,
      badgePoints: badge,
      tradeCount: stats.total,
      totalR: stats.totalR,
      winRate: stats.winRate,
      journalStreak: _streak(closed, now),
    );
  }

  static int _streak(List<Trade> closed, DateTime now) {
    final days = {
      for (final t in closed)
        if ((t.lesson ?? '').trim().isNotEmpty) _dayOf(t.closedAt!),
    };
    if (days.isEmpty) return 0;

    final today = _dayOf(now);
    // Yesterday still counts: a streak should not break at midnight just
    // because today's trade has not been journaled yet.
    var day = days.contains(today) ? today : today - 1;
    if (!days.contains(day)) return 0;

    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day--;
    }
    return streak;
  }

  Map<String, Object> toJson() => {
    'disciplineScore': disciplineScore,
    'badgePoints': badgePoints,
    'tradeCount': tradeCount,
    'totalR': totalR,
    'winRate': winRate,
    'journalStreak': journalStreak,
  };
}
