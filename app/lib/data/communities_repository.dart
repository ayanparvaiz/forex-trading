import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/community.dart';
import '../models/trader.dart';

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

  /// Every community with its points, best first — live, as people join and
  /// leave and as the leaderboard moves under them.
  Stream<List<(Community, int)>> watchRanked(Stream<List<Trader>> board) =>
      rankLive(watchAll(), board);

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
    required int avatarId,
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
        'avatarId': avatarId,
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
          isModerator: d.data()['role'] == 'moderator',
          joinedAt:
              (d.data()['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ),
    ];
  }

  /// [uid]'s role in [id] — admin, moderator or member — live; null when
  /// they are not in it.
  Stream<String?> watchRole(String id, String uid) =>
      _member(id, uid).snapshots().map((d) => d.data()?['role'] as String?);

  /// The admin making [uid] a moderator, or a member again.
  Future<void> setModerator(String id, String uid, bool moderator) =>
      _member(id, uid).update({'role': moderator ? 'moderator' : 'member'});

  /// The admin's own words about the community.
  Future<void> setDescription(String id, String description) =>
      _community(id).update({'description': description.trim()});

  /// The admin handing [id] to [to], another member. [from] becomes a
  /// member like anyone else — free to leave, or to join elsewhere.
  Future<void> handOver({
    required String id,
    required String from,
    required String to,
  }) {
    final batch = _db.batch()
      ..update(_community(id), {'createdBy': to})
      ..update(_member(id, to), {'role': 'admin'})
      ..update(_member(id, from), {'role': 'member'});
    return batch.commit();
  }

  // --- Events -----------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _events(String id) =>
      _community(id).collection('events');

  /// What is coming up in [id], soonest first — and what started in the last
  /// two hours, which may still be going on.
  Stream<List<CommunityEvent>> watchEvents(String id, {int limit = 10}) =>
      _events(id)
          .where(
            'startsAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 2)),
            ),
          )
          .orderBy('startsAt')
          .limit(limit)
          .snapshots()
          .map(
            (s) => [
              for (final d in s.docs)
                CommunityEvent(
                  id: d.id,
                  title: d.data()['title'] as String? ?? '',
                  description: d.data()['description'] as String? ?? '',
                  startsAt:
                      (d.data()['startsAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  createdBy: d.data()['createdBy'] as String? ?? '',
                  going: {
                    for (final u
                        in d.data()['going'] as List<dynamic>? ?? const [])
                      if (u is String) u,
                  },
                ),
            ],
          );

  /// The admin plans an event. Returns its id.
  Future<String> createEvent({
    required String id,
    required String me,
    required String title,
    required String description,
    required DateTime startsAt,
  }) async {
    final ref = _events(id).doc();
    await ref.set({
      'title': title.trim(),
      'description': description.trim(),
      'startsAt': Timestamp.fromDate(startsAt),
      'createdBy': me,
      'createdAt': FieldValue.serverTimestamp(),
      'going': <String>[],
    });
    return ref.id;
  }

  /// [uid] is going, or not.
  Future<void> setGoing({
    required String id,
    required String eventId,
    required String uid,
    required bool going,
  }) => _events(id).doc(eventId).update({
    'going': going
        ? FieldValue.arrayUnion([uid])
        : FieldValue.arrayRemove([uid]),
  });

  Future<void> deleteEvent(String id, String eventId) =>
      _events(id).doc(eventId).delete();

  /// The admin slowing its room down, or not.
  Future<void> setSlowMode(String id, int seconds) =>
      _community(id).update({'slowSeconds': seconds});

  /// The admin locking it, or opening it again.
  Future<void> setLocked(String id, bool locked) =>
      _community(id).update({'locked': locked});

  /// The champion of [month] — "2026-09" — or null before it is crowned.
  Future<Champion?> champion(String month) async {
    final d = await _db.collection('champions').doc(month).get();
    final data = d.data();
    if (data == null) return null;
    return Champion(
      month: month,
      communityId: data['communityId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
    );
  }

  /// The admin's rules: blank lines left out, each trimmed.
  Future<void> setRules(String id, List<String> rules) =>
      _community(id).update({
        'rules': [
          for (final r in rules)
            if (r.trim().isNotEmpty) r.trim(),
        ],
      });

  /// The admin's choice of picture.
  Future<void> setAvatar(String id, int avatarId) =>
      _community(id).update({'avatarId': avatarId});

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
      avatarId: (data['avatarId'] as num?)?.toInt(),
      locked: data['locked'] == true,
      slowSeconds: (data['slowSeconds'] as num?)?.toInt() ?? 0,
      rules: [
        for (final r in data['rules'] as List<dynamic>? ?? const [])
          if (r is String && r.isNotEmpty) r,
      ],
      titles: [
        for (final t in data['titles'] as List<dynamic>? ?? const [])
          if (t is String && monthOf(t) != null) t,
      ],
    );
  }
}

/// [communities] ranked by the points [board] gives them, again whenever
/// either changes.
///
/// Waits for the first board before saying anything, so the list does not
/// open in one order and jump to another. If the board fails, the
/// communities still come, all on zero.
///
/// Can be listened to again after it is left — switching from this week's
/// ranking back to all time's does exactly that — each time starting over
/// from [communities] and [board], which have to allow it (Firestore's do).
Stream<List<(Community, int)>> rankLive(
  Stream<List<Community>> communities,
  Stream<List<Trader>> board,
) => Stream.multi((out) {
  List<Community>? latest;
  Map<String, int>? points;
  void emit() {
    if (latest case final c? when points != null) {
      out.add(rankCommunities(c, points!));
    }
  }

  final all = communities.listen((c) {
    latest = c;
    emit();
  }, onError: out.addError);
  final standings = board.listen(
    (b) {
      points = communityPoints(b);
      emit();
    },
    onError: (Object e) {
      points ??= const {};
      emit();
    },
  );
  out.onCancel = () async {
    await all.cancel();
    await standings.cancel();
  };
});

/// Firestore when it is configured; nothing otherwise — communities need a
/// server everyone shares.
CommunitiesRepository? buildCommunitiesRepository() =>
    FirebaseBootstrap.isReady ? CommunitiesRepository() : null;
