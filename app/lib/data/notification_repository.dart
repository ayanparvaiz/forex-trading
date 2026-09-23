import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/app_notification.dart';

/// The app's notification backend.
///
/// A single instance on purpose. Every badge and list hangs off a Firestore
/// listener, and building a fresh repository per widget rebuild would close and
/// re-open those listeners constantly — which costs a full re-read each time.
NotificationRepository get notificationRepository =>
    _instance ??= FirebaseBootstrap.isReady
        ? FirestoreNotificationRepository()
        : const NullNotificationRepository();

NotificationRepository? _instance;

/// Reads and writes the notification feed.
///
/// Everything here streams rather than fetches. A badge that only updates when
/// you pull to refresh is a badge nobody trusts, and Firestore already keeps a
/// listener in sync for the price of the initial read — so live is both nicer
/// and cheaper than polling.
abstract class NotificationRepository {
  /// Unexpired notifications for [uid], newest first.
  Stream<List<AppNotification>> watch(String uid, {int limit = 50});

  /// How many are unread, live.
  Stream<int> watchUnreadCount(String uid);

  Future<void> markRead(String id);

  Future<void> markAllRead(String uid);

  /// Records that [actorUsername] did something to [recipientUid].
  ///
  /// Silent on failure. A notification is a courtesy; losing one must never
  /// break the action that caused it.
  Future<void> notify({
    required String recipientUid,
    required NotificationKind kind,
    required String actorUid,
    required String actorUsername,
    required String actorName,
    required int actorAvatarId,
    String? postId,
  });
}

class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');

  /// Unexpired, newest first.
  ///
  /// Ordering by expiresAt descending is ordering by createdAt descending,
  /// since expiry is always exactly [AppNotification.lifetime] after creation.
  /// One field for both the filter and the sort keeps this on a two-field
  /// index instead of three.
  Query<Map<String, dynamic>> _live(String uid) => _notifications
      .where('recipientUid', isEqualTo: uid)
      .where('expiresAt', isGreaterThan: Timestamp.now())
      .orderBy('expiresAt', descending: true);

  @override
  Stream<List<AppNotification>> watch(String uid, {int limit = 50}) {
    return _live(uid).limit(limit).snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }

  @override
  Stream<int> watchUnreadCount(String uid) {
    // Counted from the documents rather than an aggregate, because this has to
    // be live: an aggregate is a one-shot read and the badge would go stale the
    // moment anything arrived. The limit caps what a very busy account costs —
    // past ninety-nine the badge says "99+" anyway.
    return _notifications
        .where('recipientUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  AppNotification _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AppNotification(
      id: doc.id,
      kind: NotificationKind.fromName(data['kind'] as String?),
      actorUsername: data['actorUsername'] as String? ?? '',
      actorName: data['actorName'] as String? ?? '',
      actorAvatarId: (data['actorAvatarId'] as num?)?.toInt() ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
      postId: data['postId'] as String?,
    );
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _notifications.doc(id).update({'read': true});
    } on FirebaseException catch (error) {
      debugPrint('mark read failed: ${error.code}');
    }
  }

  @override
  Future<void> markAllRead(String uid) async {
    try {
      final unread = await _notifications
          .where('recipientUid', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .limit(100)
          .get();
      if (unread.docs.isEmpty) return;

      // One batch rather than a write each: opening the list should cost one
      // round trip, not one per row.
      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } on FirebaseException catch (error) {
      debugPrint('mark all read failed: ${error.code}');
    }
  }

  @override
  Future<void> notify({
    required String recipientUid,
    required NotificationKind kind,
    required String actorUid,
    required String actorUsername,
    required String actorName,
    required int actorAvatarId,
    String? postId,
  }) async {
    // Notifying yourself is not a notification.
    if (recipientUid == actorUid) return;

    final now = DateTime.now();
    try {
      await _notifications.add({
        'recipientUid': recipientUid,
        'actorUid': actorUid,
        'actorUsername': actorUsername,
        // Name and avatar are copied in so drawing the list costs no extra
        // reads. They are a snapshot of the moment, which is what a
        // notification is.
        'actorName': actorName,
        'actorAvatarId': actorAvatarId,
        'kind': kind.name,
        'postId': ?postId,
        'read': false,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(AppNotification.lifetime)),
      });
    } on FirebaseException catch (error) {
      // A courtesy that failed. The action it describes already happened.
      debugPrint('notify failed: ${error.code}');
    }
  }
}

/// Stand-in for when Firebase is unreachable.
///
/// Empty streams rather than an error: the bell simply shows nothing, and the
/// rest of the app carries on.
class NullNotificationRepository implements NotificationRepository {
  const NullNotificationRepository();

  @override
  Stream<List<AppNotification>> watch(String uid, {int limit = 50}) =>
      const Stream.empty();

  @override
  Stream<int> watchUnreadCount(String uid) => Stream.value(0);

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead(String uid) async {}

  @override
  Future<void> notify({
    required String recipientUid,
    required NotificationKind kind,
    required String actorUid,
    required String actorUsername,
    required String actorName,
    required int actorAvatarId,
    String? postId,
  }) async {}
}
