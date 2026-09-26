import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/community.dart';

/// The name someone asked for is already a community's.
class CommunityNameTaken implements Exception {
  const CommunityNameTaken();
}

/// Communities over Firestore. Each change is one batch shaped the way the
/// rules demand (see firestore.rules, Communities): a membership, its count,
/// the profile's communityId and the chat room move together, so nobody is
/// ever half in a community, or in two.
class CommunitiesRepository {
  CommunitiesRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _communities =>
      _db.collection('communities');
  DocumentReference<Map<String, dynamic>> _community(String id) =>
      _communities.doc(id);
  DocumentReference<Map<String, dynamic>> _member(String id, String uid) =>
      _community(id).collection('members').doc(uid);
  DocumentReference<Map<String, dynamic>> _room(String id) =>
      _db.collection('rooms').doc(Community.roomIdFor(id));
  DocumentReference<Map<String, dynamic>> _roomMember(String id, String uid) =>
      _room(id).collection('members').doc(uid);
  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _claim(String name) =>
      _db.collection('communityNames').doc(Community.claimKey(name));

  /// Every community, live. Ranked on the phone, from the leaderboard.
  Stream<List<Community>> watchAll({int limit = 200}) => _communities
      .orderBy('memberCount', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) ?_from(d)]);

  Stream<Community?> watch(String id) => _community(id).snapshots().map(_from);

  /// Whether nobody has claimed [name] yet.
  Future<bool> nameAvailable(String name) async =>
      !(await _claim(name).get()).exists;

  /// Starts a community with [me] as its admin, and its chat room — leaving
  /// [leaving] first, if [me] is in one. Throws [CommunityNameTaken].
  Future<String> create({
    required String me,
    required String username,
    required String name,
    required String description,
    String? leaving,
  }) async {
    final tidy = Community.tidyName(name);
    final ref = _communities.doc();
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    if (leaving != null) _leave(batch, me, leaving);
    batch
      ..set(ref, {
        'name': tidy,
        'nameLower': tidy.toLowerCase(),
        'description': description.trim(),
        'createdBy': me,
        'createdAt': now,
        'memberCount': 1,
      })
      ..set(_claim(tidy), {'communityId': ref.id})
      ..set(_member(ref.id, me), {
        'role': 'admin',
        'joinedAt': now,
        'username': username,
      })
      ..set(_room(ref.id), {
        'name': tidy,
        'community': ref.id,
        'memberCount': 1,
        'lastMessage': null,
        'createdAt': now,
        'updatedAt': now,
      })
      ..set(_roomMember(ref.id, me), {'joinedAt': now, 'readAt': now})
      ..update(_user(me), {'communityId': ref.id});
    try {
      await batch.commit();
    } on FirebaseException {
      // Refused — most likely the name was claimed a moment ago.
      if (!await nameAvailable(tidy)) throw const CommunityNameTaken();
      rethrow;
    }
    return ref.id;
  }

  /// Joins [id] and its chat room — leaving [leaving] first, if [me] is in
  /// one. One community at a time.
  Future<void> join({
    required String me,
    required String username,
    required String id,
    String? leaving,
  }) {
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    if (leaving != null && leaving != id) _leave(batch, me, leaving);
    batch
      ..set(_member(id, me), {
        'role': 'member',
        'joinedAt': now,
        'username': username,
      })
      ..update(_community(id), {'memberCount': FieldValue.increment(1)})
      ..set(_roomMember(id, me), {'joinedAt': now, 'readAt': now})
      ..update(_room(id), {'memberCount': FieldValue.increment(1)})
      ..update(_user(me), {'communityId': id});
    return batch.commit();
  }

  /// Leaves [id] and its chat room. What [me] posted there stays.
  Future<void> leave({required String me, required String id}) {
    final batch = _db.batch();
    _leave(batch, me, id);
    batch.update(_user(me), {'communityId': ''});
    return batch.commit();
  }

  /// The leaving half of a batch. The profile is written by the caller: to
  /// nothing, or to the community being joined instead.
  void _leave(WriteBatch batch, String me, String id) {
    batch
      ..delete(_member(id, me))
      ..update(_community(id), {'memberCount': FieldValue.increment(-1)})
      ..delete(_roomMember(id, me))
      ..update(_room(id), {'memberCount': FieldValue.increment(-1)});
  }

  /// Who is in [id], earliest first.
  Future<List<CommunityMember>> members(String id, {int limit = 200}) async {
    final page = await _community(
      id,
    ).collection('members').orderBy('joinedAt').limit(limit).get();
    return [
      for (final d in page.docs)
        CommunityMember(
          uid: d.id,
          username: d.data()['username'] as String? ?? '',
          isAdmin: d.data()['role'] == 'admin',
          joinedAt:
              (d.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ),
    ];
  }

  /// The admin's own words about the community.
  Future<void> setDescription(String id, String description) =>
      _community(id).update({'description': description.trim()});

  Community? _from(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    return Community(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Firestore when it is configured; nothing otherwise — communities need a
/// server everyone shares.
CommunitiesRepository? buildCommunitiesRepository() =>
    FirebaseBootstrap.isReady ? CommunitiesRepository() : null;
