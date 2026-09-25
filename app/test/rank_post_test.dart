import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/firestore_community_repository.dart';
import 'package:forex_trading/models/trader.dart';

/// A rank post shares a leaderboard position instead of a trade. It travels
/// through the same feed, the same ranking and the same reactions, so what is
/// worth pinning down is that it stays a different *kind* of thing all the way
/// through rather than a trade post with empty fields.
void main() {
  const author = Trader(
    id: 'rifat',
    name: 'রিফাত',
    avatarId: 1,
    disciplineScore: 96,
    badgePoints: 9,
    totalR: -4.2,
    tradeCount: 41,
    winRate: 0.41,
    journalStreak: 38,
    cohort: 'test',
  );

  FeedPost rankPost({int rank = 7, double score = 84, int reach = 0}) {
    return FeedPost.rank(
      id: 'r1',
      author: author,
      postedAt: DateTime.now(),
      rank: rank,
      disciplineScore: score,
      lesson: 'three weeks without moving a stop',
      claps: 0,
      commentCount: 0,
      reach: reach,
    );
  }

  test('a rank post carries a rank and no trade', () {
    final post = rankPost();

    expect(post.kind, PostKind.rank);
    expect(post.rank, 7);
    expect(post.disciplineScore, 84);

    // Not "0.00R on ": the card branches on kind so these are never drawn,
    // and leaving them empty is what makes a wrong branch obvious.
    expect(post.symbol, isEmpty);
    expect(post.rMultiple, 0);
    expect(post.reason, isEmpty);
  });

  test('a trade post is still a trade post', () {
    final post = FeedPost(
      id: 't1',
      author: author,
      symbol: 'EUR/USD',
      rMultiple: 1.4,
      postedAt: DateTime(2026, 1, 1),
      reason: 'reason',
      lesson: 'lesson',
      followedRules: true,
      claps: 0,
      commentCount: 0,
    );

    expect(post.kind, PostKind.trade);
    expect(post.rank, isNull);
    expect(post.disciplineScore, isNull);
  });

  test('rank posts are ranked by the same rule as everything else', () {
    // They share the feed rather than sitting in a lane of their own, so a
    // rank post nobody reads has to sink like any other post nobody reads.
    final ignored = rankPost();
    final read = FeedPost.rank(
      id: 'r2',
      author: author,
      postedAt: DateTime.now(),
      rank: 12,
      disciplineScore: 70,
      lesson: 'kept the size small',
      claps: 4,
      commentCount: 2,
      reach: 30,
    );

    expect(
      FirestoreCommunityRepository.scoreOf(read),
      greaterThan(FirestoreCommunityRepository.scoreOf(ignored)),
    );
  });
}
