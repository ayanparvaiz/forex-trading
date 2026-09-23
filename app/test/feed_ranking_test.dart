import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/firestore_community_repository.dart';
import 'package:forex_trading/models/trader.dart';

/// The ranking decides what everyone reads, so it is tested directly rather
/// than judged by scrolling. The property that matters is not any single
/// number — it is that the feed moves.
void main() {
  const author = Trader(
    id: 'rifat',
    name: 'রিফাত',
    avatarEmoji: '🦉',
    disciplineScore: 96,
    badgePoints: 9,
    totalR: -4.2,
    tradeCount: 41,
    winRate: 0.41,
    journalStreak: 38,
    cohort: 'test',
  );

  FeedPost post({
    required String id,
    required double hoursOld,
    int reach = 0,
    int claps = 0,
    int comments = 0,
  }) {
    return FeedPost(
      id: id,
      author: author,
      symbol: 'EUR/USD',
      rMultiple: 1,
      postedAt: DateTime.now().subtract(
        Duration(minutes: (hoursOld * 60).round()),
      ),
      reason: 'reason',
      lesson: 'lesson',
      followedRules: true,
      claps: claps,
      commentCount: comments,
      reach: reach,
    );
  }

  double score(FeedPost p) => FirestoreCommunityRepository.scoreOf(p);

  test('a fresh post beats an old one with far more attention', () {
    // The whole reason the feed was rewritten: under a reach-only ordering the
    // old post below would sit at the top forever.
    final old = post(id: 'old', hoursOld: 168, reach: 500, claps: 80);
    final fresh = post(id: 'fresh', hoursOld: 1, reach: 3, claps: 1);

    expect(score(fresh), greaterThan(score(old)));
  });

  test('among posts of the same age, attention decides', () {
    final quiet = post(id: 'quiet', hoursOld: 5, reach: 2);
    final busy = post(id: 'busy', hoursOld: 5, reach: 40, claps: 10);

    expect(score(busy), greaterThan(score(quiet)));
  });

  test('a comment counts for more than a like, and a like more than a view',
      () {
    final viewed = post(id: 'v', hoursOld: 3, reach: 5);
    final liked = post(id: 'l', hoursOld: 3, claps: 5);
    final discussed = post(id: 'c', hoursOld: 3, comments: 5);

    expect(score(liked), greaterThan(score(viewed)));
    expect(score(discussed), greaterThan(score(liked)));
  });

  test('unread comes before read, however popular the read one is', () {
    // Seen-ness is an ordering rule, not a discount. As a multiplier a heavily
    // read post still beat a fresh unread one, which was backwards — so the
    // feed sorts on it first and scores only within each block.
    final read = post(id: 'read', hoursOld: 2, reach: 500, claps: 200);
    final unread = post(id: 'unread', hoursOld: 2, reach: 1);
    const seen = {'read'};

    final ordered = [read, unread]..sort((a, b) {
        final aSeen = seen.contains(a.id);
        final bSeen = seen.contains(b.id);
        if (aSeen != bSeen) return aSeen ? 1 : -1;
        return score(b).compareTo(score(a));
      });

    expect(ordered.first.id, 'unread');
    // Moved down, not removed.
    expect(ordered.map((p) => p.id), ['unread', 'read']);
  });

  test('a post with no engagement at all still has a score', () {
    // Otherwise a brand new post would be ranked equal to every other empty
    // one, and never surface at all.
    final brandNew = post(id: 'new', hoursOld: 0);

    expect(score(brandNew), greaterThan(0));
  });

  test('scores fall as a post ages, every step of the way', () {
    var previous = double.infinity;
    for (final hours in [0.5, 2.0, 6.0, 24.0, 72.0, 168.0]) {
      final current = score(post(id: '$hours', hoursOld: hours, reach: 10));
      expect(current, lessThan(previous), reason: 'at $hours hours');
      previous = current;
    }
  });
}
