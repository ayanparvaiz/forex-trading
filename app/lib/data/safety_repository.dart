import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';
import 'firestore_community_repository.dart';

/// Someone you have blocked.
class BlockedAccount {
  const BlockedAccount({
    required this.uid,
    required this.username,
    required this.blockedAt,
  });

  final String uid;
  final String username;
  final DateTime blockedAt;
}

/// Blocking and reporting — the tools for keeping the community civil.
///
/// Firestore only, like messaging: both only mean anything on a shared
/// server. The rules do the enforcing; this only asks.
class SafetyRepository {
  SafetyRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _blocks(String me) =>
      _db.collection('users').doc(me).collection('blocks');

  /// Everyone you have blocked, most recent first, live.
  Stream<List<BlockedAccount>> watchBlocks(String me) {
    return _blocks(me)
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map(
          (s) => [
            for (final d in s.docs)
              BlockedAccount(
                uid: d.id,
                username: d.data()['username'] as String? ?? '',
                blockedAt: d.data()['blockedAt'] is Timestamp
                    ? (d.data()['blockedAt'] as Timestamp).toDate()
                    : DateTime.now(),
              ),
          ],
        );
  }

  /// Blocks [otherUid], and ends any connection between you in the same
  /// batch — a block that left you connected would still put them in your
  /// network and your inbox.
  ///
  /// The rules refuse messages and requests across a block in both
  /// directions, and nothing tells the other person.
  Future<void> block({
    required String me,
    required String meUsername,
    required String otherUid,
    required String otherUsername,
  }) async {
    final connection = _db
        .collection('connections')
        .doc(FirestoreCommunityRepository.pairId(meUsername, otherUsername));
    // Deleting a connection that is not there is refused by the rules, and
    // one refusal fails the whole batch — so only delete what exists.
    final connected = (await connection.get()).exists;

    final batch = _db.batch()
      ..set(_blocks(me).doc(otherUid), {
        'username': otherUsername,
        'blockedAt': FieldValue.serverTimestamp(),
      });
    if (connected) batch.delete(connection);
    await batch.commit();
  }

  /// Lifts a block. The connection it ended is not restored — reconnecting is
  /// a fresh request, from whichever of you wants to.
  Future<void> unblock(String me, String otherUid) =>
      _blocks(me).doc(otherUid).delete();
}

SafetyRepository? buildSafetyRepository() =>
    FirebaseBootstrap.isReady ? SafetyRepository() : null;
