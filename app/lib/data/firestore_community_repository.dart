import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../i18n/strings.dart';
import '../models/connection.dart';
import '../models/post_comment.dart';
import '../models/trader.dart';
import '../models/user_profile.dart';
import '../firebase/firebase_bootstrap.dart';
import 'avatars.dart';
import 'chat_repository.dart';
import 'community_repository.dart';
import 'page.dart';
import 'seen_posts.dart';

/// Picks the right backend for the community screens.
///
/// One call site decides, so no screen has to know or care which one it got.
CommunityRepository buildCommunityRepository(
  AppLanguage language, {
  String? viewerUid,
}) {
  final local = LocalCommunityRepository(language: language);
  if (!FirebaseBootstrap.isReady) return local;

  return FirestoreCommunityRepository(
    language: language,
    fallback: local,
    viewerUid: viewerUid,
  );
}

/// Which pass of the feed a cursor is in.
enum _FeedPhase { connections, reach }

/// Where the feed got to.
///
/// Opaque to every caller — the paged list only ever hands it straight back —
/// which is what lets the feed be two queries stitched together without the UI
/// knowing.
class _FeedCursor {
  const _FeedCursor({
    this.phase = _FeedPhase.connections,
    this.inner,
    this.seen = const {},
    this.ranked = const [],
    this.offset = 0,
  });

  final _FeedPhase phase;
  final DocumentSnapshot<Map<String, dynamic>>? inner;

  /// Ids already shown, so a connection's post cannot reappear in the second
  /// pass where it would also be ranked.
  final Set<String> seen;

  /// The scored window, held so it is built once rather than per page.
  ///
  /// Ranking is done on the client because the score mixes fields Firestore
  /// cannot sort by together — engagement over age. Scoring a window of recent
  /// posts once and paging through the result is one burst of reads instead of
  /// a query per page that could not express the order anyway.
  final List<FeedPost> ranked;
  final int offset;
}

/// Community data read from Firestore.
///
/// Migrating one collection at a time: whatever has not moved yet is handed to
/// [fallback], so the app keeps working at every commit instead of going dark
/// until the whole thing lands. Each delegation below is a to-do with a
/// deadline, not a design.
class FirestoreCommunityRepository implements CommunityRepository {
  FirestoreCommunityRepository({
    required this.language,
    required this.fallback,
    this.viewerUid,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final AppLanguage language;

  /// Who is reading. The feed is personalised, so it has to know.
  final String? viewerUid;

  /// What this device has already shown, used to push repeats down the feed.
  final SeenPosts seenPosts = SeenPosts();
  final FirebaseFirestore _db;

  /// Still-local implementation for the collections not yet migrated.
  final CommunityRepository fallback;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');
  CollectionReference<Map<String, dynamic>> get _connections =>
      _db.collection('connections');
  CollectionReference<Map<String, dynamic>> get _profileViews =>
      _db.collection('profileViews');
  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  /// username -> uid, remembered for the life of the repository.
  ///
  /// Usernames are never reassigned, so a claim read once is good forever.
  /// Without this, drawing one connection list would re-read the same handful
  /// of claim documents on every row.
  final Map<String, String> _uidCache = {};

  Future<String?> _uidFor(String username) async {
    final cached = _uidCache[username];
    if (cached != null) return cached;

    final claim = await _usernames.doc(username).get();
    final uid = claim.data()?['uid'] as String?;
    if (uid != null) _uidCache[username] = uid;
    return uid;
  }

  /// Document id for a relationship: both usernames, sorted, hyphen-joined.
  ///
  /// Sorting makes the id identical whichever side asks, so a relationship can
  /// never be stored twice. The hyphen is safe because usernames are limited to
  /// letters, digits and underscore — a separator that could appear inside a
  /// name would make `a_-b` and `a-_b` the same id.
  static String pairId(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}-${pair[1]}';
  }

  /// Fetches profiles for a page of uids in one query rather than one each.
  Future<List<Trader>> _tradersByUid(List<String> uids) async {
    if (uids.isEmpty) return [];

    final snapshot = await _users
        .where(FieldPath.documentId, whereIn: uids.take(30).toList())
        .get();

    // whereIn does not preserve the order it was given, and the caller's order
    // is the meaningful one — newest first.
    final byUid = {for (final d in snapshot.docs) d.id: _traderFrom(d.data())};
    return [
      for (final uid in uids)
        if (byUid[uid] != null) byUid[uid]!,
    ];
  }

  /// Builds a leaderboard row out of a profile document.
  ///
  /// Every field is read defensively. A profile written by a newer build than
  /// the one reading it should render with sensible blanks rather than throw
  /// and take the whole list down.
  Trader _traderFrom(Map<String, dynamic> data) {
    final created = DateTime.tryParse(data['createdAt'] as String? ?? '');

    return Trader(
      id: data['username'] as String? ?? '',
      name: data['displayName'] as String? ?? '',
      avatarId: Avatars.from(data['avatarId']).id,
      disciplineScore: (data['disciplineScore'] as num?)?.toDouble() ?? 0,
      badgePoints: (data['badgePoints'] as num?)?.toInt() ?? 0,
      totalR: (data['totalR'] as num?)?.toDouble() ?? 0,
      tradeCount: (data['tradeCount'] as num?)?.toInt() ?? 0,
      winRate: (data['winRate'] as num?)?.toDouble() ?? 0,
      journalStreak: (data['journalStreak'] as num?)?.toInt() ?? 0,
      // Derived on read rather than stored, so a cohort label follows the
      // language the reader picked instead of the one the account signed up in.
      cohort: created == null ? '' : UserProfile.cohortFor(created, language),
    );
  }

  @override
  Future<ResultPage<Trader>> leaderboard({
    Object? cursor,
    int limit = 12,
  }) async {
    var query = _users
        .where('ranked', isEqualTo: true)
        .orderBy('disciplineScore', descending: true)
        .orderBy('tradeCount', descending: true)
        .limit(limit);

    // The cursor is the last document of the previous page. Passing the
    // snapshot rather than its field values keeps ties stable — two traders on
    // the same score and trade count would otherwise repeat or vanish across
    // the page boundary.
    if (cursor is DocumentSnapshot) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return const ResultPage.empty();

    return ResultPage(
      items: snapshot.docs.map((d) => _traderFrom(d.data())).toList(),
      cursor: snapshot.docs.last,
      // A short page means the end. Firestore gives no total, and asking for
      // one would cost a second full read of the collection.
      hasMore: snapshot.docs.length == limit,
    );
  }

  @override
  Stream<List<Trader>> watchLeaderboard({
    int limit = CommunityRepository.leaderboardLimit,
  }) {
    // Same ordering as the paged query, so the live board and any paged view
    // of it agree about who is where. After the first snapshot Firestore sends
    // only the rows that changed, so a board of fifty that barely moves costs
    // almost nothing to keep open.
    //
    // Only ranked accounts. With no closed trades the discipline score is 100,
    // so without the filter every new sign-up would open at the top of the
    // board, above people who have kept their rules for months.
    return _users
        .where('ranked', isEqualTo: true)
        .orderBy('disciplineScore', descending: true)
        .orderBy('tradeCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => [for (final d in s.docs) _traderFrom(d.data())]);
  }

  @override
  Stream<int> watchNewPostCount(DateTime since, {int cap = 20}) {
    // Capped, because the badge only ever needs to say "a lot" past a point
    // and every document in the window is a read.
    return _posts
        .where('postedAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('postedAt')
        .limit(cap)
        .snapshots()
        .map((s) => s.docs.length);
  }

  @override
  Future<Trader?> trader(String username) async {
    // The claim document maps a username to a uid, so this is two key lookups
    // rather than a query — cheaper, and it needs no index.
    final claim = await _usernames.doc(username).get();
    final uid = claim.data()?['uid'] as String?;
    if (uid == null) return null;

    final profile = await _users.doc(uid).get();
    final data = profile.data();
    return data == null ? null : _traderFrom(data);
  }

  @override
  Future<String?> uidFor(String username) => _uidFor(username);

  @override
  Future<int?> rankOf(String username) async {
    final me = await trader(username);
    if (me == null) return null;
    // Not on the board yet, so there is no position to report.
    if (me.tradeCount < CommunityRepository.minRankedTrades) return null;

    // Counting who is ahead is one aggregate read, whatever the size of the
    // board. Walking the list to find a position would cost a read per row and
    // get slower as the app succeeds.
    //
    // Ties are resolved by trade count in the list order, but not here: two
    // people on the same score are both told the better of the two positions,
    // which is the kinder and cheaper answer.
    final ahead = await _users
        .where('ranked', isEqualTo: true)
        .where('disciplineScore', isGreaterThan: me.disciplineScore)
        .count()
        .get();

    return (ahead.count ?? 0) + 1;
  }

  // --- Connections ---------------------------------------------------------

  @override
  Future<ResultPage<Trader>> connectionsOf(
    String username, {
    Object? cursor,
    int limit = 12,
  }) async {
    final uid = await _uidFor(username);
    if (uid == null) return const ResultPage.empty();

    var query = _connections
        .where('uids', arrayContains: uid)
        .where('accepted', isEqualTo: true)
        .orderBy('requestedAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return const ResultPage.empty();

    final others = [
      for (final doc in snapshot.docs)
        (doc.data()['uids'] as List).cast<String>().firstWhere(
          (u) => u != uid,
          orElse: () => uid,
        ),
    ];

    return ResultPage(
      items: await _tradersByUid(others),
      cursor: snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  @override
  Future<ResultPage<Trader>> pendingRequestsFor(
    String username, {
    Object? cursor,
    int limit = 12,
  }) async {
    final uid = await _uidFor(username);
    if (uid == null) return const ResultPage.empty();

    var query = _connections
        .where('toUid', isEqualTo: uid)
        .where('accepted', isEqualTo: false)
        .orderBy('requestedAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return const ResultPage.empty();

    final senders = [
      for (final doc in snapshot.docs) doc.data()['fromUid'] as String,
    ];

    return ResultPage(
      items: await _tradersByUid(senders),
      cursor: snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  @override
  Future<ConnectionStatus> statusBetween(String me, String other) async {
    if (me == other) return ConnectionStatus.none;

    // A single key lookup. The sorted id means finding the relationship between
    // two specific people needs no query at all.
    //
    // "No relationship" is the common answer here, and it must not be able to
    // take the profile screen down with it: a refused or failed read means the
    // Connect button shows, which is the right default either way.
    Map<String, dynamic>? data;
    try {
      data = (await _connections.doc(pairId(me, other)).get()).data();
    } on FirebaseException catch (error) {
      debugPrint('connection status unavailable: ${error.code}');
      return ConnectionStatus.none;
    }
    if (data == null) return ConnectionStatus.none;

    if (data['accepted'] == true) return ConnectionStatus.connected;
    return data['fromUser'] == me
        ? ConnectionStatus.pendingOutgoing
        : ConnectionStatus.pendingIncoming;
  }

  @override
  Future<int> connectionCount(String username) async {
    final uid = await _uidFor(username);
    if (uid == null) return 0;

    // An aggregate, so the count costs one read rather than one per connection.
    final result = await _connections
        .where('uids', arrayContains: uid)
        .where('accepted', isEqualTo: true)
        .count()
        .get();
    return result.count ?? 0;
  }

  @override
  Future<void> sendRequest({required String from, required String to}) async {
    if (from == to) return;

    final fromUid = await _uidFor(from);
    final toUid = await _uidFor(to);
    if (fromUid == null || toUid == null) return;

    final doc = _connections.doc(pairId(from, to));

    // Checked rather than blindly written: set() would overwrite an accepted
    // connection back to pending, which is a way to silently un-friend someone.
    if ((await doc.get()).exists) return;

    // Only the request. The conversation opens when it is accepted — a request
    // is one person asking, and letting it open a chat would let anyone
    // message anyone by sending one first. The rules refuse it regardless.
    try {
      await doc.set({
        'users': [from, to]..sort(),
        'uids': [fromUid, toUid],
        'fromUser': from,
        'toUser': to,
        'fromUid': fromUid,
        'toUid': toUid,
        'accepted': false,
        'requestedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // Lost a race with the other side asking first. Already related either
      // way, so there is nothing left to do.
    }
  }

  @override
  Future<void> acceptRequest({required String me, required String from}) async {
    // The rules enforce that only the recipient may do this; the client only
    // has to ask correctly.
    //
    // Accepting opens the conversation, in the same batch, so the two people
    // are in each other's inbox the moment they are connected. A chat left
    // over from an earlier connection between them is reused rather than
    // recreated: its history is still theirs.
    final doc = _connections.doc(pairId(me, from));
    try {
      final connection = (await doc.get()).data();
      if (connection == null) return;

      final chat = _db.collection('chats').doc(doc.id);
      final batch = _db.batch()
        ..update(doc, {
          'accepted': true,
          'respondedAt': FieldValue.serverTimestamp(),
        });
      if (!(await chat.get()).exists) {
        batch.set(
          chat,
          ChatRepository.newChatFields(
            users: List<String>.from(connection['users'] as List),
            uids: List<String>.from(connection['uids'] as List),
          ),
        );
      }
      await batch.commit();
    } on FirebaseException {
      // No such request, or not ours to accept.
    }
  }

  @override
  Future<void> removeConnection({
    required String me,
    required String other,
  }) async {
    try {
      await _connections.doc(pairId(me, other)).delete();
    } on FirebaseException {
      // Already gone.
    }
  }

  // --- Profile views -------------------------------------------------------

  @override
  Future<int> viewerCount(String username) async {
    final uid = await _uidFor(username);
    if (uid == null) return 0;

    // An aggregate: the count costs one read rather than one per visitor.
    final result = await _profileViews
        .where('profileUid', isEqualTo: uid)
        .count()
        .get();
    return result.count ?? 0;
  }

  @override
  Future<ResultPage<ProfileView>> viewersOf(
    String username, {
    Object? cursor,
    int limit = 12,
  }) async {
    final uid = await _uidFor(username);
    if (uid == null) return const ResultPage.empty();

    var query = _profileViews
        .where('profileUid', isEqualTo: uid)
        .orderBy('viewedAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return const ResultPage.empty();

    return ResultPage(
      items: [
        for (final doc in snapshot.docs)
          ProfileView(
            viewer: doc.data()['viewerUsername'] as String? ?? '',
            profileId: username,
            viewedAt:
                (doc.data()['viewedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
          ),
      ],
      cursor: snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  @override
  Future<void> recordView({
    required String viewer,
    required String profileId,
  }) async {
    // Looking at your own profile is not a visit.
    if (viewer == profileId) return;

    final viewerUid = await _uidFor(viewer);
    final profileUid = await _uidFor(profileId);
    if (viewerUid == null || profileUid == null) return;

    // The id is the pair, so a repeat visit overwrites rather than adding a
    // row. The list answers who looked, not who refreshed most.
    try {
      await _profileViews.doc('${viewerUid}_$profileUid').set({
        'viewerUid': viewerUid,
        'profileUid': profileUid,
        'viewerUsername': viewer,
        'profileUsername': profileId,
        'viewedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // A failed visit record is not worth interrupting anyone's browsing.
    }
  }

  // --- Feed ----------------------------------------------------------------

  /// Which accounts the signed-in trader is connected to, cached per session.
  List<String>? _myConnectionUids;

  Future<List<String>> _connectionUidsFor(String uid) async {
    final cached = _myConnectionUids;
    if (cached != null) return cached;

    try {
      // Capped at thirty because that is the most an `whereIn` will take, and
      // beyond it the first page is already full of people you know.
      final snapshot = await _connections
          .where('uids', arrayContains: uid)
          .where('accepted', isEqualTo: true)
          .limit(30)
          .get();

      return _myConnectionUids = [
        for (final doc in snapshot.docs)
          (doc.data()['uids'] as List).cast<String>().firstWhere(
            (u) => u != uid,
            orElse: () => uid,
          ),
      ]..remove(uid);
    } on FirebaseException {
      return _myConnectionUids = const [];
    }
  }

  @override
  Future<String?> createPost({
    required String uid,
    required String username,
    required String symbol,
    required double rMultiple,
    required String reason,
    required String lesson,
    required bool followedRules,
  }) async {
    final now = DateTime.now();
    try {
      final doc = await _posts.add({
        ..._envelope(uid, username, now),
        'kind': 'trade',
        'symbol': symbol,
        'rMultiple': rMultiple,
        'reason': reason.trim(),
        'lesson': lesson.trim(),
        'followedRules': followedRules,
      });
      return doc.id;
    } on FirebaseException catch (error) {
      debugPrint('create post failed: ${error.code}');
      return null;
    }
  }

  @override
  Future<String?> createRankPost({
    required String uid,
    required String username,
    required int rank,
    required double score,
    required String lesson,
  }) async {
    final now = DateTime.now();
    try {
      final doc = await _posts.add({
        ..._envelope(uid, username, now),
        'kind': 'rank',
        // Both are what the board showed when the post was written, and both
        // are taken from this device's own numbers.
        //
        // Nothing server-side can check them yet, because discipline still
        // lives in the app rather than in Firestore — which makes this the
        // first screen where an on-device number becomes a public claim. Once
        // trades move to Firestore the rule can pin the score to the user
        // document, the way followedRules is pinned to the trade record.
        'rank': rank,
        'disciplineScore': score,
        'lesson': lesson.trim(),
      });
      return doc.id;
    } on FirebaseException catch (error) {
      debugPrint('create rank post failed: ${error.code}');
      return null;
    }
  }

  @override
  Future<FeedPost?> post(String postId) async {
    final doc = await _posts.doc(postId).get();
    final authorUid = doc.data()?['authorUid'] as String?;
    if (authorUid == null) return null;
    final authors = await _tradersByUid([authorUid]);
    return authors.isEmpty ? null : _postFrom(doc, authors.first);
  }

  /// Two prefix queries, one on the username and one on the lowercase name,
  /// merged. Firestore matches only the start of a field; matching anywhere
  /// in a name is done on the device, over the people search already knows.
  @override
  Future<List<Trader>> searchPeople(String query, {int limit = 10}) async {
    final q = CommunityRepository.normaliseQuery(query);
    if (q.isEmpty) return const [];
    Future<QuerySnapshot<Map<String, dynamic>>> startsWith(String field) =>
        _users
            .orderBy(field)
            .startAt([q])
            .endAt(['$q\uf8ff'])
            .limit(limit)
            .get();
    final pages = await Future.wait([
      startsWith('username'),
      startsWith('nameLower'),
    ]);
    final seen = <String>{};
    return [
      for (final page in pages)
        for (final d in page.docs)
          if (_traderFrom(d.data()) case final t when seen.add(t.id)) t,
    ];
  }

  /// Newest first, by expiry — which is posting time plus a fixed week, so
  /// the same order, and it lets this share the feed's index.
  @override
  Future<List<FeedPost>> postsBy(String username, {int limit = 3}) async {
    final uid = await _uidFor(username);
    if (uid == null) return const [];
    final page = await _posts
        .where('authorUid', isEqualTo: uid)
        .orderBy('expiresAt', descending: true)
        .limit(limit)
        .get();
    return _hydrate(page.docs);
  }

  /// Everything under the post first — comments, likes, views — and the post
  /// last. Stopped part-way, the post is still there, and deleting it again
  /// finishes the job.
  @override
  Future<void> deletePost(String postId) async {
    final post = _posts.doc(postId);
    for (final sub in const ['comments', 'claps', 'views']) {
      for (;;) {
        final page = await post.collection(sub).limit(400).get();
        if (page.docs.isEmpty) break;
        final batch = _db.batch();
        for (final d in page.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
        if (page.docs.length < 400) break;
      }
    }
    await post.delete();
  }

  /// The fields every post carries whatever it is about.
  Map<String, Object?> _envelope(String uid, String username, DateTime now) => {
    'authorUid': uid,
    'authorUsername': username,
    'claps': 0,
    'commentCount': 0,
    // Written explicitly, not left to default on read. Firestore's orderBy
    // skips documents missing the field entirely, so a post without reach is a
    // post the feed cannot see.
    'reach': 0,
    'postedAt': Timestamp.fromDate(now),
    'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
  };

  /// Turns post documents into cards, attaching each author's current profile.
  ///
  /// Authors are fetched fresh rather than copied into the post, so changing an
  /// avatar updates every post that person ever wrote.
  Future<List<FeedPost>> _hydrate(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) return [];

    final authors = await _tradersByUid([
      for (final doc in docs) doc.data()['authorUid'] as String,
    ]);
    final byUsername = {for (final a in authors) a.id: a};

    return [
      for (final doc in docs)
        if (byUsername[doc.data()['authorUsername']] != null)
          _postFrom(doc, byUsername[doc.data()['authorUsername']]!),
    ];
  }

  /// The feed is two lists stitched together: people you know, then everyone
  /// else by reach.
  ///
  /// Firestore cannot express "sort by whether I am connected to the author",
  /// so the ordering is done by asking twice. The cursor carries which pass we
  /// are in, where we got to, and what has already been shown — a post from a
  /// connection must not turn up again in the second pass.
  ///
  /// Expiry is a query filter in the first pass. In the second it is checked
  /// after reading, because Firestore will not order by reach while filtering
  /// on a different field — so a handful of expired documents are read and
  /// dropped. That is the cost of ranking by reach without a server, and it is
  /// small while the feed is.
  @override
  Future<ResultPage<FeedPost>> feed({Object? cursor, int limit = 8}) async {
    final state = cursor is _FeedCursor ? cursor : const _FeedCursor();

    if (state.phase == _FeedPhase.connections) {
      final page = await _connectionPosts(state, limit);
      if (page != null) return page;
      // Nobody connected, or their posts are exhausted — fall through.
    }

    return _rankedPosts(state, limit);
  }

  Future<ResultPage<FeedPost>?> _connectionPosts(
    _FeedCursor state,
    int limit,
  ) async {
    final me = viewerUid;
    if (me == null) return null;

    final friends = await _connectionUidsFor(me);
    if (friends.isEmpty) return null;

    var query = _posts
        .where('authorUid', whereIn: friends)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: true)
        .limit(limit);
    if (state.inner != null) query = query.startAfterDocument(state.inner!);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return null;

    final seen = {...state.seen, ...snapshot.docs.map((d) => d.id)};
    final more = snapshot.docs.length == limit;

    return ResultPage(
      items: await _hydrate(snapshot.docs),
      cursor: _FeedCursor(
        // Stay in this pass while there are more; otherwise hand over.
        phase: more ? _FeedPhase.connections : _FeedPhase.reach,
        inner: more ? snapshot.docs.last : null,
        seen: seen,
      ),
      // Always more to come: even with no further connection posts, the second
      // pass has not run yet.
      hasMore: true,
    );
  }

  /// How many recent posts are scored in one go.
  ///
  /// A window, not the collection. Ranking needs to compare posts against each
  /// other, and comparing everything ever written would get slower every week —
  /// so the feed considers what is recent and lets the rest expire.
  static const _rankingWindow = 60;

  /// Score for a post: engagement, decayed by age.
  ///
  /// The divisor is the whole point. Without it the most-reached post ever
  /// written sits at the top forever and the feed never moves — which is
  /// exactly what a reach-only ordering did. With it, a new post with a little
  /// attention outranks an old one with a lot, and the feed turns over on its
  /// own.
  ///
  /// Comments weigh more than likes, and likes more than views, because that
  /// is the order of how much someone had to care.
  ///
  /// Whether the reader has seen it is deliberately not part of this. It was,
  /// briefly, as a multiplier — and a heavily-read post still outranked a fresh
  /// unread one, which is the opposite of what was wanted. Seen-ness is an
  /// ordering rule, not a discount, so it lives in the sort instead.
  static double scoreOf(FeedPost post) {
    final hours = DateTime.now().difference(post.postedAt).inMinutes / 60;
    final engagement = post.reach + post.claps * 3 + post.commentCount * 5 + 1;

    return engagement / math.pow(hours + 2, 1.4);
  }

  Future<ResultPage<FeedPost>> _rankedPosts(
    _FeedCursor state,
    int limit,
  ) async {
    // The window is scored once and paged from memory afterwards.
    if (state.ranked.isNotEmpty) return _slice(state, limit);

    final snapshot = await _posts
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: true)
        .limit(_rankingWindow)
        .get();
    if (snapshot.docs.isEmpty) return const ResultPage.empty();

    final posts = await _hydrate(snapshot.docs);
    final seenBefore = await seenPosts.load();

    final ranked =
        [
          for (final post in posts)
            if (!state.seen.contains(post.id)) post,
        ]..sort((a, b) {
          // Everything unread first, then everything read, each block ordered by
          // score within itself. Read posts are moved rather than hidden —
          // somebody who checks the feed often would otherwise find it empty.
          final aSeen = seenBefore.contains(a.id);
          final bSeen = seenBefore.contains(b.id);
          if (aSeen != bSeen) return aSeen ? 1 : -1;

          return scoreOf(b).compareTo(scoreOf(a));
        });

    return _slice(
      _FeedCursor(phase: _FeedPhase.reach, seen: state.seen, ranked: ranked),
      limit,
    );
  }

  ResultPage<FeedPost> _slice(_FeedCursor state, int limit) {
    if (state.offset >= state.ranked.length) return const ResultPage.empty();

    final end = (state.offset + limit).clamp(0, state.ranked.length);
    final items = state.ranked.sublist(state.offset, end);

    return ResultPage(
      items: items,
      cursor: _FeedCursor(
        phase: _FeedPhase.reach,
        seen: {...state.seen, ...items.map((p) => p.id)},
        ranked: state.ranked,
        offset: end,
      ),
      hasMore: end < state.ranked.length,
    );
  }

  // --- Post reactions ------------------------------------------------------

  @override
  Stream<PostCounters> watchPost(String postId) {
    // Only the counts are streamed. The text of a post never changes, so
    // re-reading the whole document on every reaction would be waste.
    return _posts.doc(postId).snapshots().map((doc) {
      final data = doc.data() ?? const {};
      return PostCounters(
        claps: (data['claps'] as num?)?.toInt() ?? 0,
        commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
        reach: (data['reach'] as num?)?.toInt() ?? 0,
      );
    });
  }

  @override
  Future<bool> hasClapped(String postId, String uid) async {
    try {
      return (await _posts.doc(postId).collection('claps').doc(uid).get())
          .exists;
    } on FirebaseException {
      return false;
    }
  }

  @override
  Future<bool> toggleClap(String postId, String uid) async {
    final clap = _posts.doc(postId).collection('claps').doc(uid);
    final post = _posts.doc(postId);

    try {
      final existing = await clap.get();
      final liked = !existing.exists;

      // The clap document and the counter move together. One without the other
      // is a count that drifts from the thing it is counting — and because the
      // document id is the uid, pressing the button twice cannot double it.
      final batch = _db.batch();
      if (liked) {
        // The uid again, as a field: the id alone cannot be queried across
        // posts, and deleting an account has to find every like it left.
        batch.set(clap, {'uid': uid, 'at': FieldValue.serverTimestamp()});
        batch.update(post, {'claps': FieldValue.increment(1)});
      } else {
        batch.delete(clap);
        batch.update(post, {'claps': FieldValue.increment(-1)});
      }
      await batch.commit();
      return liked;
    } on FirebaseException catch (error) {
      debugPrint('clap failed: ${error.code}');
      return (await clap.get()).exists;
    }
  }

  @override
  Stream<List<PostComment>> watchComments(String postId, {int limit = 50}) {
    return _posts
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              PostComment(
                id: doc.id,
                authorUid: doc.data()['authorUid'] as String? ?? '',
                authorUsername: doc.data()['authorUsername'] as String? ?? '',
                authorName: doc.data()['authorName'] as String? ?? '',
                authorAvatarId:
                    (doc.data()['authorAvatarId'] as num?)?.toInt() ?? 1,
                body: doc.data()['body'] as String? ?? '',
                createdAt:
                    (doc.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              ),
          ],
        );
  }

  @override
  Future<void> addComment({
    required String postId,
    required String uid,
    required String username,
    required String name,
    required int avatarId,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final post = _posts.doc(postId);
    try {
      final batch = _db.batch();
      batch.set(post.collection('comments').doc(), {
        'authorUid': uid,
        'authorUsername': username,
        // Copied in so a thread costs one query rather than a read per row.
        'authorName': name,
        'authorAvatarId': avatarId,
        'body': trimmed.length > PostComment.maxLength
            ? trimmed.substring(0, PostComment.maxLength)
            : trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(post, {'commentCount': FieldValue.increment(1)});
      await batch.commit();
    } on FirebaseException catch (error) {
      debugPrint('comment failed: ${error.code}');
    }
  }

  @override
  Future<String?> postAuthorUid(String postId) async {
    try {
      return (await _posts.doc(postId).get()).data()?['authorUid'] as String?;
    } on FirebaseException {
      return null;
    }
  }

  /// Posts this device has already counted a view for, this session.
  ///
  /// Scrolling a card off screen and back would otherwise attempt the write
  /// again. The batch below would refuse it, but not attempting it at all is
  /// cheaper than being refused.
  final Set<String> _reachRecorded = {};

  @override
  Future<void> recordReach(String postId, String uid) async {
    if (!_reachRecorded.add(postId)) return;

    // Remembered on the device too, so the next time this feed is ranked the
    // post sinks below whatever has not been read yet.
    unawaited(seenPosts.add([postId]));

    final view = _posts.doc(postId).collection('views').doc(uid);

    try {
      // Both writes in one batch, and the view document is what guards the
      // counter. Its rule allows create but never update, so a second view by
      // the same person is refused — and because it is one batch, the refusal
      // takes the increment down with it. Reach counts people, not scrolls.
      final batch = _db.batch()
        ..set(view, {'at': FieldValue.serverTimestamp()})
        ..update(_posts.doc(postId), {'reach': FieldValue.increment(1)});
      await batch.commit();
    } on FirebaseException {
      // Already seen, or offline. Reach is a ranking signal, not an
      // accounting record — losing one is not worth surfacing.
    }
  }

  FeedPost _postFrom(
    DocumentSnapshot<Map<String, dynamic>> doc,
    Trader author,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    // Posts written before rank sharing existed carry no kind at all, so the
    // absence of the field means "trade" rather than meaning nothing.
    if (data['kind'] == 'rank') {
      return FeedPost.rank(
        id: doc.id,
        author: author,
        postedAt: (data['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        rank: (data['rank'] as num?)?.toInt() ?? 0,
        disciplineScore: (data['disciplineScore'] as num?)?.toDouble() ?? 0,
        lesson: data['lesson'] as String? ?? '',
        claps: (data['claps'] as num?)?.toInt() ?? 0,
        commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
        reach: (data['reach'] as num?)?.toInt() ?? 0,
      );
    }

    return FeedPost(
      id: doc.id,
      author: author,
      symbol: data['symbol'] as String? ?? '',
      rMultiple: (data['rMultiple'] as num?)?.toDouble() ?? 0,
      postedAt: (data['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'] as String? ?? '',
      lesson: data['lesson'] as String? ?? '',
      followedRules: data['followedRules'] as bool? ?? false,
      claps: (data['claps'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      reach: (data['reach'] as num?)?.toInt() ?? 0,
    );
  }
}
