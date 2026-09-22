import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.dart';
import '../models/connection.dart';
import '../models/trader.dart';
import 'mock_community.dart';
import 'page.dart';
import 'seed_accounts.dart';

/// Reads and writes everything social: leaderboard, feed, connections, views.
///
/// Every list method is paged. Nothing here ever returns a whole collection —
/// a leaderboard of ten thousand would hang a cheap phone and burn the read
/// quota in a single pull, and the fix has to be in the shape of the API rather
/// than remembered at each call site.
abstract class CommunityRepository {
  Future<ResultPage<Trader>> leaderboard({Object? cursor, int limit = 12});

  Future<ResultPage<FeedPost>> feed({Object? cursor, int limit = 8});

  Future<Trader?> trader(String username);

  /// Who opened [username]'s profile, most recent first.
  Future<ResultPage<ProfileView>> viewersOf(
    String username, {
    Object? cursor,
    int limit = 12,
  });

  Future<ResultPage<Trader>> connectionsOf(
    String username, {
    Object? cursor,
    int limit = 12,
  });

  /// Requests [username] has received and not answered.
  Future<ResultPage<Trader>> pendingRequestsFor(
    String username, {
    Object? cursor,
    int limit = 12,
  });

  Future<ConnectionStatus> statusBetween(String me, String other);

  Future<int> connectionCount(String username);

  Future<void> sendRequest({required String from, required String to});

  Future<void> acceptRequest({required String me, required String from});

  /// Withdraws a request, declines one, or disconnects — all the same write.
  Future<void> removeConnection({required String me, required String other});

  Future<void> recordView({required String viewer, required String profileId});
}

/// On-device implementation over the seeded accounts.
///
/// Connections and profile views persist; the leaderboard and feed come from
/// the seed data. The Firestore version keeps this interface exactly, which is
/// why the cursor is opaque.
class LocalCommunityRepository implements CommunityRepository {
  LocalCommunityRepository({
    required this.language,
    SharedPreferences? prefs,
  }) : _injected = prefs;

  final AppLanguage language;
  final SharedPreferences? _injected;
  SharedPreferences? _cached;

  static const _connectionsKey = 'community.connections';
  static const _viewsKey = 'community.views';

  /// Profile views are capped so the list cannot grow without bound on a
  /// device that never syncs anywhere.
  static const _maxStoredViews = 500;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  // --- Paging helper -------------------------------------------------------

  /// Slices an in-memory list using an integer offset cursor.
  ///
  /// The offset is the whole trick for local data. Firestore will hand back a
  /// DocumentSnapshot instead, and because callers only ever pass the cursor
  /// straight back, nothing above this line changes.
  ResultPage<T> _slice<T>(List<T> all, Object? cursor, int limit) {
    final start = cursor is int ? cursor : 0;
    if (start >= all.length) return const ResultPage.empty();

    final end = (start + limit).clamp(0, all.length);
    return ResultPage(
      items: all.sublist(start, end),
      cursor: end,
      hasMore: end < all.length,
    );
  }

  // --- Stored state --------------------------------------------------------

  Future<List<Connection>> _connections() async {
    final raw = (await _prefs).getString(_connectionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Connection.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveConnections(List<Connection> connections) async {
    await (await _prefs).setString(
      _connectionsKey,
      jsonEncode(connections.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<ProfileView>> _views() async {
    final raw = (await _prefs).getString(_viewsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ProfileView.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- Leaderboard and feed ------------------------------------------------

  @override
  Future<ResultPage<Trader>> leaderboard({Object? cursor, int limit = 12}) async {
    final ranked = MockCommunity.rank(MockCommunity.traders(language));
    return _slice(ranked, cursor, limit);
  }

  @override
  Future<ResultPage<FeedPost>> feed({Object? cursor, int limit = 8}) async {
    return _slice(MockCommunity.liveFeed(language), cursor, limit);
  }

  @override
  Future<Trader?> trader(String username) async {
    final all = MockCommunity.traders(language);
    for (final t in all) {
      if (t.id == username) return t;
    }
    return null;
  }

  // --- Connections ---------------------------------------------------------

  @override
  Future<ConnectionStatus> statusBetween(String me, String other) async {
    if (me == other) return ConnectionStatus.none;

    for (final c in await _connections()) {
      if (c.involves(me) && c.involves(other)) return c.statusFor(me);
    }
    return ConnectionStatus.none;
  }

  @override
  Future<int> connectionCount(String username) async {
    final connections = await _connections();
    return connections.where((c) => c.accepted && c.involves(username)).length;
  }

  @override
  Future<void> sendRequest({required String from, required String to}) async {
    if (from == to) return;

    final connections = await _connections();
    // Already related in some way — do not stack a second request on top.
    if (connections.any((c) => c.involves(from) && c.involves(to))) return;

    connections.add(
      Connection(
        from: from,
        to: to,
        accepted: false,
        requestedAt: DateTime.now(),
      ),
    );
    await _saveConnections(connections);
  }

  @override
  Future<void> acceptRequest({required String me, required String from}) async {
    final connections = await _connections();
    final index = connections.indexWhere(
      // Only the recipient may accept. Accepting your own outgoing request
      // would let anyone connect to anyone.
      (c) => !c.accepted && c.from == from && c.to == me,
    );
    if (index < 0) return;

    connections[index] = connections[index].accept();
    await _saveConnections(connections);
  }

  @override
  Future<void> removeConnection({
    required String me,
    required String other,
  }) async {
    final connections = await _connections()
      ..removeWhere((c) => c.involves(me) && c.involves(other));
    await _saveConnections(connections);
  }

  @override
  Future<ResultPage<Trader>> connectionsOf(
    String username, {
    Object? cursor,
    int limit = 12,
  }) async {
    final connections = (await _connections())
        .where((c) => c.accepted && c.involves(username))
        .toList()
      ..sort((a, b) => (b.respondedAt ?? b.requestedAt)
          .compareTo(a.respondedAt ?? a.requestedAt));

    final traders = <Trader>[];
    for (final c in connections) {
      final t = await trader(c.otherThan(username));
      if (t != null) traders.add(t);
    }
    return _slice(traders, cursor, limit);
  }

  @override
  Future<ResultPage<Trader>> pendingRequestsFor(
    String username, {
    Object? cursor,
    int limit = 12,
  }) async {
    final incoming = (await _connections())
        .where((c) => !c.accepted && c.to == username)
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    final traders = <Trader>[];
    for (final c in incoming) {
      final t = await trader(c.from);
      if (t != null) traders.add(t);
    }
    return _slice(traders, cursor, limit);
  }

  // --- Profile views -------------------------------------------------------

  @override
  Future<void> recordView({
    required String viewer,
    required String profileId,
  }) async {
    // Looking at your own profile is not a visit.
    if (viewer == profileId) return;

    final views = await _views()
      // One row per viewer per profile: the list answers "who looked", not
      // "how many times", and repeats would bury everyone else.
      ..removeWhere((v) => v.viewer == viewer && v.profileId == profileId);

    views.add(
      ProfileView(
        viewer: viewer,
        profileId: profileId,
        viewedAt: DateTime.now(),
      ),
    );

    views.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    final trimmed =
        views.length > _maxStoredViews ? views.sublist(0, _maxStoredViews) : views;

    await (await _prefs).setString(
      _viewsKey,
      jsonEncode(trimmed.map((v) => v.toJson()).toList()),
    );
  }

  @override
  Future<ResultPage<ProfileView>> viewersOf(
    String username, {
    Object? cursor,
    int limit = 12,
  }) async {
    final views = (await _views())
        .where((v) => v.profileId == username)
        .toList()
      ..sort((a, b) => b.viewedAt.compareTo(a.viewedAt));

    return _slice(views, cursor, limit);
  }

  /// Gives the seeded accounts a starting web of connections and visits, so a
  /// fresh install does not present an empty social graph.
  Future<void> seedGraph(String me) async {
    if ((await _connections()).isNotEmpty) return;

    final others = SeedAccounts.all
        .where((a) => a.username != me)
        .map((a) => a.username)
        .toList();

    final connections = <Connection>[];
    final now = DateTime.now();

    // A few accepted connections, and a couple of requests waiting on you.
    for (var i = 0; i < 5 && i < others.length; i++) {
      connections.add(
        Connection(
          from: others[i],
          to: me,
          accepted: true,
          requestedAt: now.subtract(Duration(days: 10 - i)),
          respondedAt: now.subtract(Duration(days: 9 - i)),
        ),
      );
    }
    for (var i = 5; i < 8 && i < others.length; i++) {
      connections.add(
        Connection(
          from: others[i],
          to: me,
          accepted: false,
          requestedAt: now.subtract(Duration(hours: (i - 4) * 7)),
        ),
      );
    }

    await _saveConnections(connections);

    for (var i = 0; i < 9 && i < others.length; i++) {
      await recordView(viewer: others[i], profileId: me);
    }
  }
}
