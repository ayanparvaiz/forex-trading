import '../core/week.dart';

/// Two connections, one week: whose discipline score is higher by Sunday
/// midnight, Dhaka time.
class Challenge {
  const Challenge({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.pair,
    required this.week,
    required this.accepted,
  });

  final String id;
  final String fromUid;
  final String toUid;

  /// The connection between the two — usernames, sorted.
  final String pair;

  /// "2026-W40".
  final String week;
  final bool accepted;

  String otherOf(String me) => fromUid == me ? toUid : fromUid;

  /// The id it is kept under: one a week between any two.
  static String idFor(String week, String pair) => '${week}_$pair';
}

/// Where one trader stood in a week: their score, when they closed enough
/// trades to have one.
class WeekStanding {
  const WeekStanding({this.score, this.trades = 0});

  static const none = WeekStanding();

  /// The week's discipline score; null with too few trades to count.
  final double? score;
  final int trades;

  /// From a profile's fields, for [week]: this week's numbers, or last
  /// week's once the week is over.
  factory WeekStanding.of(Map<String, dynamic> profile, String week) {
    double? n(Object? v) => v is num ? v.toDouble() : null;
    int i(Object? v) => v is num ? v.toInt() : 0;
    if (profile['weekBoard'] == week) {
      return WeekStanding(
        score: n(profile['weekScore']),
        trades: i(profile['weekTrades']),
      );
    }
    if (profile['lastWeekBoard'] == week) {
      return WeekStanding(
        score: n(profile['lastWeekScore']),
        trades: i(profile['lastWeekTrades']),
      );
    }
    return none;
  }
}

enum ChallengeResult { ahead, behind, level, open }

/// Who is ahead — or, once [week] is over, who won — from where each stood.
ChallengeResult resultFor(WeekStanding me, WeekStanding them) {
  final a = me.score, b = them.score;
  if (a == null && b == null) return ChallengeResult.open;
  if (b == null) return ChallengeResult.ahead;
  if (a == null) return ChallengeResult.behind;
  if ((a - b).abs() < 0.05) return ChallengeResult.level;
  return a > b ? ChallengeResult.ahead : ChallengeResult.behind;
}

/// Whether [week] is over by [now].
bool weekOver(String week, DateTime now) => week != weekId(now);
