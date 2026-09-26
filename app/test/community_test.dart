import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/models/community.dart';
import 'package:forex_trading/models/trader.dart';

Trader trader(String id, {String? community}) => Trader(
  id: id,
  name: id,
  avatarId: 1,
  disciplineScore: 80,
  badgePoints: 0,
  totalR: 0,
  tradeCount: 10,
  winRate: 0.5,
  journalStreak: 0,
  cohort: '',
  communityId: community,
);

Community community(String id, String name, {int members = 1}) => Community(
  id: id,
  name: name,
  description: '',
  createdBy: 'u',
  memberCount: members,
  createdAt: DateTime(2026, 9, 26),
);

void main() {
  test('points come from where members stand on the board', () {
    final board = [
      trader('a', community: 'bulls'), // #1 → 50
      trader('b'), // #2, in none
      trader('c', community: 'bears'), // #3 → 48
      trader('d', community: 'bulls'), // #4 → 47
    ];
    expect(communityPoints(board), {'bulls': 97, 'bears': 48});
  });

  test('nobody below the top 50 counts', () {
    final board = [
      for (var i = 0; i < 60; i++)
        trader('t$i', community: i < 50 ? null : 'late'),
    ];
    expect(communityPoints(board), isEmpty);
  });

  test('ranked by points, then size, then name', () {
    final ranked = rankCommunities(
      [
        community('x', 'Xray', members: 9),
        community('y', 'alpha', members: 3),
        community('z', 'Beta', members: 3),
        community('w', 'Top', members: 1),
      ],
      {'w': 80, 'x': 10},
    );
    expect(
      [for (final (c, _) in ranked) c.name],
      ['Top', 'Xray', 'alpha', 'Beta'],
    );
    expect(ranked.first.$2, 80);
  });

  test('a name is claimed however it is spaced or cased', () {
    expect(Community.claimKey('  Dhaka   Traders '), 'dhaka traders');
    expect(Community.tidyName('  Dhaka   Traders '), 'Dhaka Traders');
  });

  test("a community's room, and a room's community", () {
    expect(Community.roomIdFor('abc123'), 'c_abc123');
    expect(Community.ofRoom('c_abc123'), 'abc123');
    expect(Community.ofRoom('global'), isNull);
  });
}
