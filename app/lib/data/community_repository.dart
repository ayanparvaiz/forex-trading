import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.dart';
import '../models/connection.dart';
import '../models/post_comment.dart';
import '../models/trader.dart';
import 'mock_community.dart';
import 'page.dart';

/// Reads and writes everything social: leaderboard, feed, connections, views.
///
/// Every list method is paged. Nothing here ever returns a whole collection —
/// a leaderboard of ten thousand would hang a cheap phone and burn the read
/// quota in a single pull, and the fix has to be in the shape of the API rather
/// than remembered at each call site.
abstract class CommunityRepository {
  Future<ResultPage<Trader>> leaderboard({Object? cursor, int limit = 12});

  /// The top of the leaderboard, live.
  ///
  /// A listener rather than pages, because the board is capped at
  /// [leaderboardLimit] anyway and its whole point is that it moves: when the
  /// worker writes someone's new score, their row should move while you are
  /// looking at it, not on the next pull-to-refresh.
  Stream<List<Trader>> watchLeaderboard({int limit = leaderboardLimit});

  /// How many posts have appeared since [since], live, up to [cap].
  ///
  /// A count rather than the posts themselves. Dropping new posts into a feed
  /// while someone is reading it moves the card under their thumb; saying
  /// "3 new posts" and letting them choose when to look is the difference
  /// between a live feed and a jumpy one.
  Stream<int> watchNewPostCount(DateTime since, {int cap = 20});

  Future<ResultPage<FeedPost>> feed({Object? cursor, int limit = 8});

  Future<Trader?> trader(String username);

  /// The account id behind a username, or null if there is no such account.
  ///
  /// Notifications are addressed by id rather than by username, because that
  /// is what the security rules can verify.
  Future<String?> uidFor(String username);

  /// Where [username] sits on the leaderboard, 1-based, or null if unranked.
  ///
  /// Asked separately from the list because the list stops at
  /// [leaderboardLimit]. Someone in 300th place still has to be told where
  /// they stand, and paging 300 rows to find out would be absurd.
  Future<int?> rankOf(String username);

  /// How many rows the leaderboard shows.
  ///
  /// A cap rather than endless scrolling: past the first page or two nobody is
  /// reading names, and a trader's own position is pinned on screen anyway.
  static const leaderboardLimit = 50;

  /// Closed trades needed before an account is ranked at all.
  ///
  /// With nothing closed, nothing has been broken, and the discipline score is
  /// 100 — so without a floor every new account would top the board. Mirrors
  /// MIN_RANKED_TRADES in worker/src/stats.js, which is what actually decides.
  static const minRankedTrades = 5;

  /// How many distinct people have opened [username]'s profile.
  Future<int> viewerCount(String username);

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

  // --- Post reactions ------------------------------------------------------

  /// Live counts for one post.
  Stream<PostCounters> watchPost(String postId);

  /// Whether [uid] has already reacted to [postId].
  Future<bool> hasClapped(String postId, String uid);

  /// Adds or removes [uid]'s reaction. Returns the new state.
  Future<bool> toggleClap(String postId, String uid);

  Stream<List<PostComment>> watchComments(String postId, {int limit = 50});

  Future<void> addComment({
    required String postId,
    required String uid,
    required String username,
    required String name,
    required int avatarId,
    required String body,
  });

  /// Who wrote [postId], so a reaction can notify them.
  Future<String?> postAuthorUid(String postId);

  /// Records that [uid] has seen [postId]. Counted once per person, ever.
  Future<void> recordReach(String postId, String uid);

  /// Publishes a journal entry to the feed. Returns the new post's id.
  ///
  /// Takes the lesson as well as the reason, because a post with no lesson is
  /// a result with nothing anyone can learn from — and this feed exists to be
  /// learned from.
  Future<String?> createPost({
    required String uid,
    required String username,
    required String symbol,
    required double rMultiple,
    required String reason,
    required String lesson,
    required bool followedRules,
  });

  /// Publishes a leaderboard position to the feed. Returns the new post's id.
  ///
  /// [rank] and [score] are what the board showed at this moment, written into
  /// the post rather than recomputed later.
  Future<String?> createRankPost({
    required String uid,
    required String username,
    required int rank,
    required double score,
    required String lesson,
  });

  /// One post, for opening it from a chat it was shared into. Null when it
  /// has been deleted.
  Future<FeedPost?> post(String postId);

  /// Deletes your own post, and every comment, like and view on it — they
  /// mean nothing without it.
  Future<void> deletePost(String postId);
}

/// On-device implementation over the seeded accounts.
///
/// Connections and profile views persist; the leaderboard and feed come from
/// the seed data. The Firestore version keeps this interface exactly, which is
/// why the cursor is opaque.
class LocalCommunityRepository implements CommunityRepository {
  LocalCommunityRepository({required this.language, SharedPreferences? prefs})
    : _injected = prefs;

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
  Future<ResultPage<Trader>> leaderboard({
    Object? cursor,
    int limit = 12,
  }) async {
    final ranked = MockCommunity.rank(MockCommunity.traders(language));
    return _slice(ranked, cursor, limit);
  }

  /// Nobody else posts to an on-device feed.
  @override
  Stream<int> watchNewPostCount(DateTime since, {int cap = 20}) =>
      Stream.value(0);

  /// One snapshot and done: nothing on this device changes anyone else's row.
  @override
  Stream<List<Trader>> watchLeaderboard({
    int limit = CommunityRepository.leaderboardLimit,
  }) async* {
    yield MockCommunity.rank(
      MockCommunity.traders(language),
    ).take(limit).toList();
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

  @override
  Future<String?> uidFor(String username) async => username;

  // Reactions are a Firestore feature. Offline, a post has no live counts and
  // nothing to react to — the empty implementations keep the UI working rather
  // than making every card check which backend it got.

  @override
  Stream<PostCounters> watchPost(String postId) => const Stream.empty();

  @override
  Future<bool> hasClapped(String postId, String uid) async => false;

  @override
  Future<bool> toggleClap(String postId, String uid) async => false;

  @override
  Stream<List<PostComment>> watchComments(String postId, {int limit = 50}) =>
      Stream.value(const []);

  @override
  Future<void> addComment({
    required String postId,
    required String uid,
    required String username,
    required String name,
    required int avatarId,
    required String body,
  }) async {}

  @override
  Future<String?> postAuthorUid(String postId) async => null;

  @override
  Future<void> recordReach(String postId, String uid) async {}

  @override
  Future<String?> createPost({
    required String uid,
    required String username,
    required String symbol,
    required double rMultiple,
    required String reason,
    required String lesson,
    required bool followedRules,
  }) async => null;

  @override
  Future<String?> createRankPost({
    required String uid,
    required String username,
    required int rank,
    required double score,
    required String lesson,
  }) async => null;

  @override
  Future<FeedPost?> post(String postId) async {
    for (final p in MockCommunity.liveFeed(language)) {
      if (p.id == postId) return p;
    }
    return null;
  }

  /// Nothing to delete: this device never publishes to the feed.
  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<int?> rankOf(String username) async {
    final ranked = MockCommunity.rank(MockCommunity.traders(language));
    final index = ranked.indexWhere((t) => t.id == username);
    return index < 0 ? null : index + 1;
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
    final connections =
        (await _connections())
            .where((c) => c.accepted && c.involves(username))
            .toList()
          ..sort(
            (a, b) => (b.respondedAt ?? b.requestedAt).compareTo(
              a.respondedAt ?? a.requestedAt,
            ),
          );

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
    final incoming =
        (await _connections())
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
    final trimmed = views.length > _maxStoredViews
        ? views.sublist(0, _maxStoredViews)
        : views;

    await (await _prefs).setString(
      _viewsKey,
      jsonEncode(trimmed.map((v) => v.toJson()).toList()),
    );
  }

  @override
  Future<int> viewerCount(String username) async =>
      (await _views()).where((v) => v.profileId == username).length;

  @override
  Future<ResultPage<ProfileView>> viewersOf(
    String username, {
    Object? cursor,
    int limit = 12,
  }) async {
    final views =
        (await _views()).where((v) => v.profileId == username).toList()
          ..sort((a, b) => b.viewedAt.compareTo(a.viewedAt));

    return _slice(views, cursor, limit);
  }
}
