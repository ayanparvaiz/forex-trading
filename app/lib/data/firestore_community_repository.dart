import 'package:cloud_firestore/cloud_firestore.dart';

import '../i18n/strings.dart';
import '../models/connection.dart';
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

  // --- Not yet migrated ----------------------------------------------------

  @override
  Future<ResultPage<FeedPost>> feed({Object? cursor, int limit = 8}) =>
      fallback.feed(cursor: cursor, limit: limit);

  @override
  Future<ResultPage<ProfileView>> viewersOf(
    String username, {
    Object? cursor,
    int limit = 12,
  }) => fallback.viewersOf(username, cursor: cursor, limit: limit);

  @override
  Future<ResultPage<Trader>> connectionsOf(
    String username, {
    Object? cursor,
    int limit = 12,
  }) => fallback.connectionsOf(username, cursor: cursor, limit: limit);

  @override
  Future<ResultPage<Trader>> pendingRequestsFor(
    String username, {
    Object? cursor,
    int limit = 12,
  }) => fallback.pendingRequestsFor(username, cursor: cursor, limit: limit);

  @override
  Future<ConnectionStatus> statusBetween(String me, String other) =>
      fallback.statusBetween(me, other);

  @override
  Future<int> connectionCount(String username) =>
      fallback.connectionCount(username);

  @override
  Future<void> sendRequest({required String from, required String to}) =>
      fallback.sendRequest(from: from, to: to);

  @override
  Future<void> acceptRequest({required String me, required String from}) =>
      fallback.acceptRequest(me: me, from: from);

  @override
  Future<void> removeConnection({required String me, required String other}) =>
      fallback.removeConnection(me: me, other: other);

  @override
  Future<void> recordView({
    required String viewer,
    required String profileId,
  }) => fallback.recordView(viewer: viewer, profileId: profileId);
}
