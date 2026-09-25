import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/community_repository.dart';
import 'package:forex_trading/data/page.dart';
import 'package:forex_trading/data/seed_accounts.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/connection.dart';
import 'package:forex_trading/models/trader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walks every page of [fetch], guarding against a cursor that never advances.
Future<List<T>> drain<T>(
  Future<ResultPage<T>> Function({Object? cursor, int limit}) fetch, {
  int limit = 4,
}) async {
  final all = <T>[];
  Object? cursor;
  var guard = 0;

  while (true) {
    final page = await fetch(cursor: cursor, limit: limit);
    all.addAll(page.items);
    if (!page.hasMore) break;
    cursor = page.cursor;
    if (++guard > 200) fail('pagination did not terminate');
  }
  return all;
}

void main() {
  late LocalCommunityRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalCommunityRepository(
      language: AppLanguage.bn,
      prefs: await SharedPreferences.getInstance(),
    );
  });

  group('paging', () {
    test('walks the whole leaderboard without gaps or repeats', () async {
      final all = await drain(repo.leaderboard, limit: 4);

      expect(all, hasLength(SeedAccounts.all.length));
      expect(all.map((t) => t.id).toSet(), hasLength(all.length));
    });

    test('keeps the ranking order across page boundaries', () async {
      final all = await drain(repo.leaderboard, limit: 3);

      for (var i = 1; i < all.length; i++) {
        expect(
          all[i - 1].disciplineScore,
          greaterThanOrEqualTo(all[i].disciplineScore),
        );
      }
    });

    test(
      'first page is exactly the page size, and says there is more',
      () async {
        final page = await repo.leaderboard(limit: 5);

        expect(page.items, hasLength(5));
        expect(page.hasMore, isTrue);
        expect(page.cursor, 5);
      },
    );

    test('the last page reports no more', () async {
      final page = await repo.leaderboard(cursor: 18, limit: 10);

      expect(page.items, hasLength(2));
      expect(page.hasMore, isFalse);
    });

    test(
      'a cursor past the end returns nothing rather than throwing',
      () async {
        final page = await repo.leaderboard(cursor: 9999, limit: 10);

        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
      },
    );

    test('pages the feed too', () async {
      final all = await drain(repo.feed, limit: 3);

      expect(all.length, greaterThan(6));
      expect(all.map((p) => p.id).toSet(), hasLength(all.length));
      // Newest first is preserved across pages.
      for (var i = 1; i < all.length; i++) {
        expect(all[i - 1].postedAt.isBefore(all[i].postedAt), isFalse);
      }
    });
  });

  group('connections', () {
    test(
      'a request shows as outgoing to one side, incoming to the other',
      () async {
        await repo.sendRequest(from: 'ayan', to: 'rifat');

        expect(
          await repo.statusBetween('ayan', 'rifat'),
          ConnectionStatus.pendingOutgoing,
        );
        expect(
          await repo.statusBetween('rifat', 'ayan'),
          ConnectionStatus.pendingIncoming,
        );
      },
    );

    test('accepting connects both sides', () async {
      await repo.sendRequest(from: 'ayan', to: 'rifat');
      await repo.acceptRequest(me: 'rifat', from: 'ayan');

      expect(
        await repo.statusBetween('ayan', 'rifat'),
        ConnectionStatus.connected,
      );
      expect(
        await repo.statusBetween('rifat', 'ayan'),
        ConnectionStatus.connected,
      );
      expect(await repo.connectionCount('ayan'), 1);
      expect(await repo.connectionCount('rifat'), 1);
    });

    test('only the recipient can accept', () async {
      await repo.sendRequest(from: 'ayan', to: 'rifat');

      // Accepting your own outgoing request would let anyone connect to anyone.
      await repo.acceptRequest(me: 'ayan', from: 'ayan');
      await repo.acceptRequest(me: 'ayan', from: 'rifat');

      expect(
        await repo.statusBetween('ayan', 'rifat'),
        ConnectionStatus.pendingOutgoing,
      );
    });

    test(
      'a second request does not stack on an existing relationship',
      () async {
        await repo.sendRequest(from: 'ayan', to: 'rifat');
        await repo.sendRequest(from: 'ayan', to: 'rifat');
        await repo.sendRequest(from: 'rifat', to: 'ayan');

        await repo.acceptRequest(me: 'rifat', from: 'ayan');
        expect(await repo.connectionCount('ayan'), 1);
      },
    );

    test('you cannot connect to yourself', () async {
      await repo.sendRequest(from: 'ayan', to: 'ayan');

      expect(await repo.statusBetween('ayan', 'ayan'), ConnectionStatus.none);
      expect(await repo.connectionCount('ayan'), 0);
    });

    test(
      'removing works for withdrawing, declining and disconnecting',
      () async {
        await repo.sendRequest(from: 'ayan', to: 'rifat');
        await repo.removeConnection(me: 'rifat', other: 'ayan');
        expect(
          await repo.statusBetween('ayan', 'rifat'),
          ConnectionStatus.none,
        );

        await repo.sendRequest(from: 'ayan', to: 'rifat');
        await repo.acceptRequest(me: 'rifat', from: 'ayan');
        await repo.removeConnection(me: 'ayan', other: 'rifat');
        expect(await repo.connectionCount('ayan'), 0);
      },
    );

    test('pending requests list only what is waiting on you', () async {
      await repo.sendRequest(from: 'rifat', to: 'ayan');
      await repo.sendRequest(from: 'nusrat', to: 'ayan');
      await repo.sendRequest(from: 'ayan', to: 'imran');

      final pending = await drain<Trader>(
        ({cursor, limit = 12}) =>
            repo.pendingRequestsFor('ayan', cursor: cursor, limit: limit),
      );

      expect(pending.map((t) => t.id), containsAll(['rifat', 'nusrat']));
      expect(pending.map((t) => t.id), isNot(contains('imran')));
    });

    test('the connection list pages', () async {
      for (final account in SeedAccounts.all.skip(1).take(9)) {
        await repo.sendRequest(from: account.username, to: 'ayan');
        await repo.acceptRequest(me: 'ayan', from: account.username);
      }

      final page = await repo.connectionsOf('ayan', limit: 4);
      expect(page.items, hasLength(4));
      expect(page.hasMore, isTrue);

      final all = await drain<Trader>(
        ({cursor, limit = 4}) =>
            repo.connectionsOf('ayan', cursor: cursor, limit: limit),
      );
      expect(all, hasLength(9));
    });
  });

  group('profile views', () {
    test('records who looked, newest first', () async {
      await repo.recordView(viewer: 'rifat', profileId: 'ayan');
      await repo.recordView(viewer: 'nusrat', profileId: 'ayan');

      final page = await repo.viewersOf('ayan');
      expect(page.items.map((v) => v.viewer), ['nusrat', 'rifat']);
    });

    test('one row per viewer, however many times they look', () async {
      await repo.recordView(viewer: 'rifat', profileId: 'ayan');
      await repo.recordView(viewer: 'rifat', profileId: 'ayan');
      await repo.recordView(viewer: 'rifat', profileId: 'ayan');

      final page = await repo.viewersOf('ayan');
      expect(page.items, hasLength(1));
    });

    test('looking at your own profile is not a visit', () async {
      await repo.recordView(viewer: 'ayan', profileId: 'ayan');

      expect((await repo.viewersOf('ayan')).items, isEmpty);
    });

    test('views are scoped to the profile that was opened', () async {
      await repo.recordView(viewer: 'rifat', profileId: 'ayan');
      await repo.recordView(viewer: 'rifat', profileId: 'nusrat');

      expect((await repo.viewersOf('ayan')).items, hasLength(1));
      expect((await repo.viewersOf('nusrat')).items, hasLength(1));
      expect((await repo.viewersOf('imran')).items, isEmpty);
    });

    test('the viewer list pages', () async {
      for (final account in SeedAccounts.all.skip(1)) {
        await repo.recordView(viewer: account.username, profileId: 'ayan');
      }

      final page = await repo.viewersOf('ayan', limit: 5);
      expect(page.items, hasLength(5));
      expect(page.hasMore, isTrue);

      final all = await drain<ProfileView>(
        ({cursor, limit = 5}) =>
            repo.viewersOf('ayan', cursor: cursor, limit: limit),
      );
      expect(all, hasLength(19));
    });
  });
}
