import 'badge.dart';

/// Another learner, as they appear on the leaderboard and in the feed.
class Trader {
  const Trader({
    required this.id,
    required this.name,
    required this.avatarEmoji,
    required this.disciplineScore,
    required this.badgePoints,
    required this.totalR,
    required this.tradeCount,
    required this.winRate,
    required this.journalStreak,
    required this.cohort,
    this.isYou = false,
  });

  /// Username — unique, and the account they log in with.
  final String id;
  final String name;
  final String avatarEmoji;

  /// Net winning trades. Drives the badge.
  final int badgePoints;

  BadgeRank get badge => BadgeRank.of(badgePoints);

  /// 0–100. This is what the leaderboard sorts by.
  final double disciplineScore;

  /// Cumulative R. Shown, but deliberately never used for ranking.
  final double totalR;

  final int tradeCount;
  final double winRate;

  /// Consecutive days with a journal entry.
  final int journalStreak;

  /// Which monthly batch they are learning with.
  final String cohort;

  final bool isYou;
}

/// A shared journal entry in the community feed.
///
/// Note what a post carries: the reasoning, the rule check and the lesson.
/// There is no "signal" field, and there never will be one.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.author,
    required this.symbol,
    required this.rMultiple,
    required this.postedAt,
    required this.reason,
    required this.lesson,
    required this.followedRules,
    required this.claps,
    required this.commentCount,
    this.reach = 0,
  });

  final String id;
  final Trader author;
  final String symbol;

  /// Result in R. Can be negative — losing posts are the useful ones.
  final double rMultiple;

  final DateTime postedAt;

  /// Why they took the trade.
  final String reason;

  /// What they took away from it.
  final String lesson;

  /// Whether the trade broke none of their own rules.
  final bool followedRules;

  final int claps;
  final int commentCount;

  /// How many distinct people have seen this post.
  ///
  /// Counts people, not scrolls — one view per reader, forever. It is the
  /// signal the feed ranks strangers' posts by, once posts from people you
  /// know have been shown.
  final int reach;
}
