import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/people_search.dart';
import 'package:forex_trading/data/recent_searches.dart';
import 'package:forex_trading/models/trader.dart';
import 'package:shared_preferences/shared_preferences.dart';

Trader person(String id, String name, {int avatarId = 1}) => Trader(
  id: id,
  name: name,
  avatarId: avatarId,
  disciplineScore: 80,
  badgePoints: 0,
  totalR: 0,
  tradeCount: 10,
  winRate: 0.5,
  journalStreak: 0,
  cohort: '',
);

void main() {
  final rifat = person('rifat', 'রিফাত হাসান');
  final mehedi = person('mehedi', 'মেহেদী হাসান');
  final mim = person('mim', 'মাইশা মিম');
  final ayan = person('ayan', 'Ayan Parvaiz');
  final raihan = person('raihan', 'Raihan Kabir');
  final jarin = person('jarin', 'Jarin Tasnia');

  // I am niloy: connected to rifat; mehedi knows two of my connections, mim
  // one; raihan and jarin are on the board.
  final pool = PeoplePool(
    connections: [rifat],
    mutual: {'mehedi': (mehedi, 2), 'mim': (mim, 1)},
    leaderboard: [raihan, rifat, jarin, ayan],
  );

  group('suggestions', () {
    test('connections, then most mutual, then the board', () {
      final hits = suggestPeople(pool, me: 'niloy');
      expect(
        [for (final h in hits) h.username],
        ['rifat', 'mehedi', 'mim', 'raihan', 'jarin', 'ayan'],
      );
      expect(hits.first.reason, PersonReason.connected);
      expect(hits.first.rank, 2); // rifat is also #2 on the board
      expect(hits[1].mutualCount, 2);
    });

    test('never me, never someone I blocked', () {
      final hits = suggestPeople(pool, me: 'ayan', exclude: {'mehedi'});
      final names = [for (final h in hits) h.username];
      expect(names, isNot(contains('ayan')));
      expect(names, isNot(contains('mehedi')));
    });
  });

  group('results', () {
    test('a name matches from any word, in Bangla too', () {
      final hits = rankPeople('হাসান', pool, const [], me: 'niloy');
      expect([for (final h in hits) h.username], ['rifat', 'mehedi']);
    });

    test('an @username, in any case', () {
      final hits = rankPeople('@MIM', pool, const [], me: 'niloy');
      expect(hits.single.username, 'mim');
    });

    test('a start beats a middle, then closeness decides', () {
      // "ai" is inside raihan and inside "Parvaiz" — both middles, so the
      // board decides: raihan is #1, ayan #4.
      expect(
        [for (final h in rankPeople('ai', pool, const [], me: 'x')) h.username],
        ['raihan', 'ayan'],
      );
      // "r": rifat (connected) and raihan (board) start with it; jarin and
      // "Parvaiz" only have it inside.
      expect(
        [for (final h in rankPeople('r', pool, const [], me: 'x')) h.username],
        ['rifat', 'raihan', 'jarin', 'ayan'],
      );
    });

    test('the server adds whoever is not already there, once', () {
      final stranger = person('rimi', 'Rimi Das');
      final hits = rankPeople('ri', pool, [rifat, stranger], me: 'niloy');
      // rifat starts with it; jarin has it inside; rimi only the server knew.
      expect([for (final h in hits) h.username], ['rifat', 'jarin', 'rimi']);
      expect(hits.last.reason, PersonReason.match);
      expect(hits.last.rank, isNull);
    });

    test('nothing typed is not a search', () {
      expect(rankPeople('  ', pool, [rifat], me: 'niloy'), isEmpty);
    });
  });

  group('recent searches', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('newest first, once each', () async {
      final recent = RecentSearches(owner: 'u1', prefs: prefs);
      await recent.add(rifat);
      await recent.add(mim);
      await recent.add(rifat);
      expect(
        [for (final p in await recent.load()) p.username],
        ['rifat', 'mim'],
      );
    });

    test('kept to the last ten', () async {
      final recent = RecentSearches(owner: 'u1', prefs: prefs);
      for (var i = 0; i < 14; i++) {
        await recent.add(person('p$i', 'P $i'));
      }
      final kept = await recent.load();
      expect(kept, hasLength(RecentSearches.max));
      expect(kept.first.username, 'p13');
    });

    test('removed one by one, or all at once', () async {
      final recent = RecentSearches(owner: 'u1', prefs: prefs);
      await recent.add(rifat);
      await recent.add(mim);
      await recent.remove('rifat');
      expect([for (final p in await recent.load()) p.username], ['mim']);
      await recent.clear();
      expect(await recent.load(), isEmpty);
    });

    test('each account has its own', () async {
      await RecentSearches(owner: 'u1', prefs: prefs).add(rifat);
      expect(await RecentSearches(owner: 'u2', prefs: prefs).load(), isEmpty);
    });
  });
}
