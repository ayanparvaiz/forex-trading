import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/chat.dart';
import 'chat_repository.dart';

/// Rooms — conversations for everyone — over Firestore. There is one, the
/// Global room, made by hand; see the rules for what anyone may do in it.
///
/// Unlike a chat between two people, a room cannot keep a count per member
/// on its document: every message would have to touch every member. So each
/// member keeps how far they have read, and "unread" is counted from that —
/// one small aggregate read when something new arrives.
class RoomRepository {
  RoomRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const globalId = 'global';
  static const pageSize = ChatRepository.pageSize;

  DocumentReference<Map<String, dynamic>> _room(String id) =>
      _db.collection('rooms').doc(id);
  DocumentReference<Map<String, dynamic>> _member(String id, String uid) =>
      _room(id).collection('members').doc(uid);
  CollectionReference<Map<String, dynamic>> _messages(String id) =>
      _room(id).collection('messages');

  Stream<RoomInfo?> watchRoom(String id) =>
      _room(id).snapshots().map(_roomFrom);

  /// Your membership, live: null while you have not joined.
  Stream<RoomMembership?> watchMembership(String id, String uid) =>
      _member(id, uid).snapshots().map((d) {
        final data = d.data();
        if (data == null) return null;
        // Not yet stamped by the server: it is about to be now.
        DateTime time(Object? v) =>
            v is Timestamp ? v.toDate() : DateTime.now();
        return RoomMembership(
          joinedAt: time(data['joinedAt']),
          readAt: time(data['readAt']),
        );
      });

  /// Joins, and counts you in, in one write.
  Future<void> join(String id, String uid) {
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch()
      ..set(_member(id, uid), {'joinedAt': now, 'readAt': now})
      ..update(_room(id), {'memberCount': FieldValue.increment(1)});
    return batch.commit();
  }

  /// Leaves, and counts you out. The messages you wrote stay.
  Future<void> leave(String id, String uid) {
    final batch = _db.batch()
      ..delete(_member(id, uid))
      ..update(_room(id), {'memberCount': FieldValue.increment(-1)});
    return batch.commit();
  }

  Stream<List<ChatMessage>> watchLatest(String id) => _messages(id)
      .orderBy('sentAt', descending: true)
      .limit(pageSize)
      .snapshots(includeMetadataChanges: true)
      .map((s) => [for (final d in s.docs) messageFromDoc(d)]);

  Future<List<ChatMessage>> olderThan(String id, Object cursor) async {
    final snapshot = await _messages(id)
        .orderBy('sentAt', descending: true)
        .startAfterDocument(cursor as DocumentSnapshot)
        .limit(pageSize)
        .get();
    return [for (final d in snapshot.docs) messageFromDoc(d)];
  }

  Future<ChatMessage?> message(String id, String messageId) async {
    final doc = await _messages(id).doc(messageId).get();
    return doc.exists ? messageFromDoc(doc) : null;
  }

  /// Sends as [name] (@[username]) — which the rules check against your
  /// profile — and moves the room's preview, in one batch. Writing is also
  /// reading: your mark moves past everything before it.
  Future<void> send({
    required String roomId,
    required String me,
    required String name,
    required String username,
    required String text,
    ReplyRef? replyTo,
    bool forwarded = false,
    MessageAttachment? attachment,
  }) {
    final message = _messages(roomId).doc();
    final batch = _db.batch()
      ..set(message, {
        'senderUid': me,
        'senderName': name,
        'senderUsername': username,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
        'unsent': false,
        if (replyTo != null)
          'replyTo': {'id': replyTo.id, 'senderUid': replyTo.senderUid},
        if (forwarded) 'forwarded': true,
        'attachment': ?attachment?.toJson(),
      })
      ..update(_room(roomId), {
        'lastMessage': {
          'id': message.id,
          'senderUid': me,
          'senderName': name,
          'text': text,
          'unsent': false,
          'attachmentType': ?attachment?.type,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..update(_member(roomId, me), {'readAt': FieldValue.serverTimestamp()});
    return batch.commit();
  }

  Future<void> unsend({
    required String roomId,
    required String me,
    required ChatMessage message,
    required bool isLatest,
  }) {
    final batch = _db.batch()
      ..update(_messages(roomId).doc(message.id), {
        'text': '',
        'unsent': true,
        // Anything shared with it goes too.
        'attachment': FieldValue.delete(),
      });
    if (isLatest) {
      batch.update(_room(roomId), {
        'lastMessage': {
          'id': message.id,
          'senderUid': me,
          'senderName': message.senderName ?? '',
          'text': '',
          'unsent': true,
        },
      });
    }
    return batch.commit();
  }

  /// I have the room open: everything before now is read.
  Future<void> markRead(String roomId, String me) =>
      _member(roomId, me).update({'readAt': FieldValue.serverTimestamp()});

  /// Messages since [since] — what is unread for a member who last looked
  /// then. My own come after my mark, since sending moves it.
  Future<int> unreadSince(String roomId, DateTime since) async {
    final result = await _messages(
      roomId,
    ).where('sentAt', isGreaterThan: Timestamp.fromDate(since)).count().get();
    return result.count ?? 0;
  }

  RoomInfo? _roomFrom(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final updated = data['updatedAt'];
    final updatedAt = updated is Timestamp ? updated.toDate() : DateTime.now();
    final last = data['lastMessage'];
    return RoomInfo(
      id: doc.id,
      name: data['name'] as String? ?? 'Global',
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAt,
      lastMessage: last is Map
          ? ChatPreview(
              id: last['id'] as String? ?? '',
              senderUid: last['senderUid'] as String? ?? '',
              senderName: last['senderName'] as String?,
              text: last['text'] as String? ?? '',
              unsent: last['unsent'] as bool? ?? false,
              sentAt: updatedAt,
              attachmentType: last['attachmentType'] as String?,
            )
          : null,
    );
  }
}

/// Firestore when it is configured; nothing otherwise.
RoomRepository? buildRoomRepository() =>
    FirebaseBootstrap.isReady ? RoomRepository() : null;
