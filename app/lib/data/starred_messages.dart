import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/chat.dart';
import 'chat_repository.dart';
import 'room_repository.dart';

/// A message starred, to find again. Which one only: the message itself is
/// read when it is shown, so an unsent one is gone here too.
class StarredRef {
  const StarredRef({
    required this.conversationId,
    required this.messageId,
    required this.room,
    required this.starredAt,
    this.otherUid,
    this.otherUsername,
  });

  final String conversationId;
  final String messageId;

  /// A room — Global or a community's — rather than a chat between two.
  final bool room;
  final DateTime starredAt;

  /// In a chat, who it is with — to open it by.
  final String? otherUid;
  final String? otherUsername;

  String get id => starId(conversationId, messageId);
}

/// The id a star is kept under: the conversation's and the message's.
String starId(String conversationId, String messageId) =>
    '${conversationId}__$messageId';

/// Where one person's starred messages are kept: users/{uid}/starred.
class StarredMessages {
  StarredMessages({FirebaseFirestore? db, this.chats, this.rooms})
    : _injected = db;

  final FirebaseFirestore? _injected;

  /// Asked for when first used, so a test can stand in without Firebase.
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;
  final ChatRepository? chats;
  final RoomRepository? rooms;

  /// Most kept at once; the list shows the newest this many.
  static const limit = 200;

  CollectionReference<Map<String, dynamic>> _starred(String uid) =>
      _db.collection('users').doc(uid).collection('starred');

  /// Everything [uid] starred, newest star first.
  Stream<List<StarredRef>> watchAll(String uid) => _starred(uid)
      .orderBy('starredAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) ?_from(d.data())]);

  /// Which messages in [conversationId] [uid] starred, by id.
  Stream<Set<String>> watchIn(String uid, String conversationId) =>
      _starred(uid)
          .where('conversationId', isEqualTo: conversationId)
          .snapshots()
          .map(
            (s) => {
              for (final d in s.docs)
                if (d.data()['messageId'] case final String id) id,
            },
          );

  Future<void> star(
    String uid, {
    required String conversationId,
    required String messageId,
    required bool room,
    String? otherUid,
    String? otherUsername,
  }) => _starred(uid).doc(starId(conversationId, messageId)).set({
    'conversationId': conversationId,
    'messageId': messageId,
    'room': room,
    'starredAt': FieldValue.serverTimestamp(),
    'otherUid': ?otherUid,
    'otherUsername': ?otherUsername,
  });

  Future<void> unstar(String uid, String conversationId, String messageId) =>
      _starred(uid).doc(starId(conversationId, messageId)).delete();

  /// The message [ref] points to, as it is now; null when it cannot be read.
  Future<ChatMessage?> message(StarredRef ref) async {
    try {
      return ref.room
          ? await rooms?.message(ref.conversationId, ref.messageId)
          : await chats?.message(ref.conversationId, ref.messageId);
    } catch (_) {
      // A room left, or a chat gone: nothing to show.
      return null;
    }
  }

  static StarredRef? _from(Map<String, dynamic> data) {
    final conversation = data['conversationId'];
    final message = data['messageId'];
    if (conversation is! String || message is! String) return null;
    return StarredRef(
      conversationId: conversation,
      messageId: message,
      room: data['room'] == true,
      starredAt: (data['starredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      otherUid: data['otherUid'] as String?,
      otherUsername: data['otherUsername'] as String?,
    );
  }
}

/// Firestore when it is configured; nothing otherwise.
StarredMessages? buildStarredMessages() => FirebaseBootstrap.isReady
    ? StarredMessages(
        chats: buildChatRepository(),
        rooms: buildRoomRepository(),
      )
    : null;
