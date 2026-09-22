import 'dart:math' as math;

/// The five rungs of the badge ladder.
///
/// Earned from trade outcomes: every winning trade is a point, every loser
/// takes one back. Someone who was Golden last week and traded badly this week
/// falls out of it — the ladder has to be losable or it means nothing.
enum BadgeTier {
  bronze(threshold: 0, emoji: '🥉', bn: 'ব্রোঞ্জ', en: 'Bronze'),
  silver(threshold: 25, emoji: '🥈', bn: 'সিলভার', en: 'Silver'),
  platinum(threshold: 60, emoji: '💠', bn: 'প্ল্যাটিনাম', en: 'Platinum'),
  diamond(threshold: 120, emoji: '💎', bn: 'ডায়মন্ড', en: 'Diamond'),
  golden(threshold: 200, emoji: '👑', bn: 'গোল্ডেন', en: 'Golden');

  const BadgeTier({
    required this.threshold,
    required this.emoji,
    required this.bn,
    required this.en,
  });

  /// Badge points needed to reach this tier.
  final int threshold;
  final String emoji;
  final String bn;
  final String en;

  String label(bool bangla) => bangla ? bn : en;

  /// Points between Golden levels, once the top tier is reached.
  static const goldenStep = 50;

  bool get isTop => this == BadgeTier.golden;
}

/// Where a trader sits on the ladder right now.
class BadgeRank {
  const BadgeRank({
    required this.tier,
    required this.points,
    required this.level,
    required this.pointsToNext,
    required this.progress,
  });

  final BadgeTier tier;

  /// Net winning trades: every win is +1, every loss −1, floored at zero.
  final int points;

  /// Golden only. 1 at 200 points, 2 at 250, and so on. Zero below Golden.
  ///
  /// The top tier keeps counting instead of capping, so the best traders still
  /// have somewhere to go.
  final int level;

  /// Points still needed for the next tier or Golden level.
  final int pointsToNext;

  /// How far through the current step, 0..1.
  final double progress;

  /// `গোল্ডেন ৩` / `Golden 3`, or just the tier name below Golden.
  String label(bool bangla) {
    final name = tier.label(bangla);
    return tier.isTop ? '$name $level' : name;
  }

  static BadgeRank of(int rawPoints) {
    final points = math.max(0, rawPoints);

    var tier = BadgeTier.bronze;
    for (final t in BadgeTier.values) {
      if (points >= t.threshold) tier = t;
    }

    if (tier.isTop) {
      final over = points - BadgeTier.golden.threshold;
      final level = over ~/ BadgeTier.goldenStep + 1;
      final into = over % BadgeTier.goldenStep;
      return BadgeRank(
        tier: tier,
        points: points,
        level: level,
        pointsToNext: BadgeTier.goldenStep - into,
        progress: into / BadgeTier.goldenStep,
      );
    }

    final next = BadgeTier.values[tier.index + 1];
    final span = next.threshold - tier.threshold;
    final into = points - tier.threshold;

    return BadgeRank(
      tier: tier,
      points: points,
      level: 0,
      pointsToNext: next.threshold - points,
      progress: span == 0 ? 0 : into / span,
    );
  }

  /// The tier above this one, or null once Golden is reached.
  BadgeTier? get nextTier =>
      tier.isTop ? null : BadgeTier.values[tier.index + 1];
}
