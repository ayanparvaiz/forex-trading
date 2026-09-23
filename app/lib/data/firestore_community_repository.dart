import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../i18n/strings.dart';
import '../models/connection.dart';
import '../models/post_comment.dart';
import '../models/trader.dart';
import '../models/user_profile.dart';
import '../firebase/firebase_bootstrap.dart';
import 'avatars.dart';
import 'community_repository.dart';
import 'page.dart';

/// Picks the right backend for the community screens.
///
/// One call site decides, so no screen has to know or care which one it got.
CommunityRepository buildCommunityRepository(AppLanguage language) {
  final local = LocalCommunityRepository(language: language);
  if (!FirebaseBootstrap.isReady) return local;

  return FirestoreCommunityRepository(language: language, fallback: local);
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
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final AppLanguage language;
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
      avatarEmoji: Avatars.from(data['avatarId']).emoji,
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

    // Counting who is ahead is one aggregate read, whatever the size of the
    // board. Walking the list to find a position would cost a read per row and
    // get slower as the app succeeds.
    //
    // Ties are resolved by trade count in the list order, but not here: two
    // people on the same score are both told the better of the two positions,
    // which is the kinder and cheaper answer.
    final ahead = await _users
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
        (doc.data()['uids'] as List)
            .cast<String>()
            .firstWhere((u) => u != uid, orElse: () => uid),
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
    try {
      await _connections.doc(pairId(me, from)).update({
        'accepted': true,
        'respondedAt': FieldValue.serverTimestamp(),
      });
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
    final result =
        await _profileViews.where('profileUid', isEqualTo: uid).count().get();
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

  @override
  Future<ResultPage<FeedPost>> feed({Object? cursor, int limit = 8}) async {
    // Expiry is filtered in the query, not after reading, so an expired post
    // never reaches a client at all — the seven-day life is enforced by the
    // database rather than remembered by the UI.
    //
    // Ordering by expiresAt descending is ordering by postedAt descending:
    // expiry is always exactly seven days after posting. Using one field for
    // both the filter and the sort keeps this on an automatic single-field
    // index instead of needing a composite one.
    var query = _posts
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt', descending: true)
        .limit(limit);
    if (cursor is DocumentSnapshot) query = query.startAfterDocument(cursor);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return const ResultPage.empty();

    // Authors are fetched fresh rather than copied into the post, so changing
    // an avatar updates every post that person ever wrote.
    final authors = await _tradersByUid([
      for (final doc in snapshot.docs) doc.data()['authorUid'] as String,
    ]);
    final byUsername = {for (final a in authors) a.id: a};

    return ResultPage(
      items: [
        for (final doc in snapshot.docs)
          if (byUsername[doc.data()['authorUsername']] != null)
            _postFrom(doc, byUsername[doc.data()['authorUsername']]!),
      ],
      cursor: snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
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
        batch.set(clap, {'at': FieldValue.serverTimestamp()});
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

  FeedPost _postFrom(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Trader author,
  ) {
    final data = doc.data();
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
    );
  }
}
