import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/chat.dart';

/// Who is on the other end of a conversation.
class ChatPartner {
  const ChatPartner({
    required this.uid,
    required this.username,
    required this.name,
    required this.avatarId,
  });

  final String uid;
  final String username;
  final String name;
  final int avatarId;
}

/// Conversations, messages and presence, over Firestore.
///
/// Firestore only: messaging between people needs a server both of them can
/// reach, and there is no honest on-device version of it. With no Firebase
/// configured, [buildChatRepository] returns null and the inbox says so.
///
/// Everything here leans on Firestore's offline cache, which is on by default
/// on phones: a conversation opened before paints from disk at once and the
/// listener only fetches what changed, and a message written offline is
/// queued and shown as pending until it lands.
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Messages per page. The newest page is live; older pages load on scroll.
  static const pageSize = 30;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');
  CollectionReference<Map<String, dynamic>> get _connections =>
      _db.collection('connections');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _presence =>
      _db.collection('presence');
  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  /// The fields of a brand-new conversation, exactly as the rules require.
  ///
  /// Both people's marks start at the moment of creation and both counts at
  /// zero. Shared with the connection request, which opens the chat in the
  /// same batch.
  static Map<String, Object?> newChatFields({
    required List<String> users,
    required List<String> uids,
  }) {
    final now = FieldValue.serverTimestamp();
    return {
      'uids': uids,
      'users': users,
      'createdAt': now,
      'updatedAt': now,
      'lastMessage': null,
      'unread': {for (final u in uids) u: 0},
      'readAt': {for (final u in uids) u: now},
      'deliveredAt': {for (final u in uids) u: now},
    };
  }

  // --- Conversations --------------------------------------------------------

  Stream<List<ChatThread>> watchThreads(String uid, {int limit = 50}) {
    return _chats
        .where('uids', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => [for (final d in s.docs) ?_threadFrom(d)]);
  }

  Stream<ChatThread?> watchThread(String chatId) =>
      _chats.doc(chatId).snapshots().map(_threadFrom);

  /// Makes sure the conversation for an accepted connection exists.
  ///
  /// Accepting a request opens the chat; this covers connections accepted
  /// before messaging existed. An existing chat is returned whatever the
  /// connection's state, because its history stays readable after a
  /// disconnect. False when there is no chat and no accepted connection.
  Future<bool> ensureChat(String chatId) async {
    if ((await _chats.doc(chatId).get()).exists) return true;

    final connection = await _connections.doc(chatId).get();
    final data = connection.data();
    if (data == null || data['accepted'] != true) return false;

    try {
      await _chats
          .doc(chatId)
          .set(
            newChatFields(
              users: List<String>.from(data['users'] as List),
              uids: List<String>.from(data['uids'] as List),
            ),
          );
    } on FirebaseException catch (error) {
      // The other person opened it in the same moment. It exists either way.
      debugPrint('chat $chatId create raced: ${error.code}');
    }
    return true;
  }

  /// Opens a conversation for every accepted connection that does not have
  /// one yet — the ones accepted before messaging existed — so everyone you
  /// are connected to is in the inbox. Two queries, and a write only where
  /// something is missing. Pending requests are left alone: they get a
  /// conversation when they are accepted, not before.
  Future<void> ensureChatsForConnections(String uid) async {
    // Ordered so the query uses the index the profile screen already needs
    // for "your connections, newest first".
    final connections = await _connections
        .where('uids', arrayContains: uid)
        .where('accepted', isEqualTo: true)
        .orderBy('requestedAt', descending: true)
        .limit(100)
        .get();
    final existing = await _chats
        .where('uids', arrayContains: uid)
        .limit(200)
        .get();
    final have = {for (final d in existing.docs) d.id};

    for (final c in connections.docs) {
      if (have.contains(c.id)) continue;
      final data = c.data();
      try {
        await _chats
            .doc(c.id)
            .set(
              newChatFields(
                users: List<String>.from(data['users'] as List),
                uids: List<String>.from(data['uids'] as List),
              ),
            );
      } on FirebaseException catch (error) {
        debugPrint('backfill chat ${c.id} skipped: ${error.code}');
      }
    }
  }

  /// Whether the two people are connected — accepted, not just requested —
  /// which is what sending needs.
  Future<bool> isConnected(String chatId) async =>
      (await _connections.doc(chatId).get()).data()?['accepted'] == true;

  /// [isConnected], live: a conversation that is open when the other person
  /// disconnects or blocks has to close then, not the next time it opens.
  Stream<bool> watchConnected(String chatId) => _connections
      .doc(chatId)
      .snapshots()
      .map((d) => d.data()?['accepted'] == true)
      .distinct();

  // --- Messages -------------------------------------------------------------

  /// The newest page, live. Metadata changes are included so a message
  /// flips from pending to sent when the server acknowledges it, even though
  /// none of its fields change.
  Stream<List<ChatMessage>> watchLatest(String chatId) {
    return _messages(chatId)
        .orderBy('sentAt', descending: true)
        .limit(pageSize)
        .snapshots(includeMetadataChanges: true)
        .map((s) => [for (final d in s.docs) _messageFrom(d)]);
  }

  /// The page before [cursor], newest first. Fetched once rather than
  /// watched: old messages only ever change by being unsent, and the live
  /// page covers anything recent.
  Future<List<ChatMessage>> olderThan(String chatId, Object cursor) async {
    final snapshot = await _messages(chatId)
        .orderBy('sentAt', descending: true)
        .startAfterDocument(cursor as DocumentSnapshot)
        .limit(pageSize)
        .get();
    return [for (final d in snapshot.docs) _messageFrom(d)];
  }

  /// Sends a message and moves the conversation's preview in one batch.
  ///
  /// Not awaited by the screen: the message appears from the local cache at
  /// once, marked pending, and turns into a tick when the server has it.
  /// Offline, the write waits in the queue and goes when the phone does.
  Future<void> send({
    required String chatId,
    required String me,
    required String other,
    required String text,
  }) {
    final message = _messages(chatId).doc();
    final batch = _db.batch()
      ..set(message, {
        'senderUid': me,
        'text': text,
        'sentAt': FieldValue.serverTimestamp(),
        'unsent': false,
      })
      ..update(_chats.doc(chatId), {
        'lastMessage': {
          'id': message.id,
          'senderUid': me,
          'text': text,
          'unsent': false,
        },
        'updatedAt': FieldValue.serverTimestamp(),
        FieldPath(['unread', other]): FieldValue.increment(1),
        // Writing in a conversation is reading it.
        FieldPath(['readAt', me]): FieldValue.serverTimestamp(),
        // And sending ends the typing, in the same write, so "typing…" and
        // the message it was about never show at the same time.
        FieldPath(['typing', me]): FieldValue.delete(),
      });
    return batch.commit();
  }

  /// I am typing. Called at most every [typingRefresh] while the box has
  /// text — one small write per few seconds of typing, not per keystroke.
  Future<void> setTyping(String chatId, String me) =>
      _chats.doc(chatId).update({
        FieldPath(['typing', me]): FieldValue.serverTimestamp(),
      });

  /// I have stopped: the box is empty, or I have left the conversation.
  Future<void> clearTyping(String chatId, String me) =>
      _chats.doc(chatId).update({
        FieldPath(['typing', me]): FieldValue.delete(),
      });

  /// Blanks a message for both people. The preview follows when it was the
  /// newest one, because the rules require the preview to match its message.
  Future<void> unsend({
    required String chatId,
    required String me,
    required String messageId,
    required bool isLatest,
  }) {
    final batch = _db.batch()
      ..update(_messages(chatId).doc(messageId), {'text': '', 'unsent': true});
    if (isLatest) {
      batch.update(_chats.doc(chatId), {
        'lastMessage': {
          'id': messageId,
          'senderUid': me,
          'text': '',
          'unsent': true,
        },
      });
    }
    return batch.commit();
  }

  // --- Marks ----------------------------------------------------------------

  /// I have the conversation open: everything before now is read.
  Future<void> markRead(String chatId, String me) {
    return _chats.doc(chatId).update({
      FieldPath(['readAt', me]): FieldValue.serverTimestamp(),
      FieldPath(['deliveredAt', me]): FieldValue.serverTimestamp(),
      FieldPath(['unread', me]): 0,
    });
  }

  /// My app has received these conversations: their newest messages are
  /// delivered. One batch however many chats caught up at once.
  Future<void> markDelivered(Iterable<String> chatIds, String me) {
    final batch = _db.batch();
    for (final id in chatIds) {
      batch.update(_chats.doc(id), {
        FieldPath(['deliveredAt', me]): FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  /// Puts the unread dot back without changing what the other person sees:
  /// their ticks stay blue, as they do in WhatsApp.
  Future<void> markUnread(String chatId, String me) {
    return _chats.doc(chatId).update({
      FieldPath(['unread', me]): 1,
    });
  }

  // --- People and presence --------------------------------------------------

  /// Names and avatars for the people behind these uids, thirty at a time —
  /// the most a single `whereIn` can ask for.
  Future<Map<String, ChatPartner>> partners(Iterable<String> uids) async {
    final all = uids.toSet().toList();
    final out = <String, ChatPartner>{};
    for (var i = 0; i < all.length; i += 30) {
      final chunk = all.sublist(i, (i + 30).clamp(0, all.length));
      final snapshot = await _users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snapshot.docs) {
        final data = d.data();
        out[d.id] = ChatPartner(
          uid: d.id,
          username: data['username'] as String? ?? '',
          name: data['displayName'] as String? ?? '',
          avatarId: (data['avatarId'] as num?)?.toInt() ?? 1,
        );
      }
    }
    return out;
  }

  /// I am here. Stamped by the server, which is the only time the rules
  /// accept.
  Future<void> beat(String uid) =>
      _presence.doc(uid).set({'lastActiveAt': FieldValue.serverTimestamp()});

  /// When each of these people was last around, live. At most thirty — the
  /// inbox only ever shows presence for the conversations on screen.
  Stream<Map<String, DateTime>> watchPresence(List<String> uids) {
    if (uids.isEmpty) return Stream.value(const {});
    return _presence
        .where(FieldPath.documentId, whereIn: uids.take(30).toList())
        .snapshots()
        .map(
          (s) => {
            for (final d in s.docs)
              if (d.data()['lastActiveAt'] case final Timestamp t)
                d.id: t.toDate(),
          },
        );
  }

  // --- Decoding -------------------------------------------------------------

  ChatThread? _threadFrom(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;

    // A server timestamp this phone has written but the server has not yet
    // confirmed arrives as null. It is about to be "now", so it is read as
    // now — reading it as zero would drop a chat you just wrote in to the
    // bottom of the inbox until the acknowledgement came back.
    DateTime time(Object? v) => v is Timestamp ? v.toDate() : DateTime.now();

    Map<String, DateTime> marks(Object? v) => {
      if (v is Map)
        for (final e in v.entries) e.key as String: time(e.value),
    };

    final updatedAt = time(data['updatedAt']);
    final last = data['lastMessage'];

    return ChatThread(
      id: doc.id,
      uids: List<String>.from(data['uids'] as List? ?? const []),
      users: List<String>.from(data['users'] as List? ?? const []),
      updatedAt: updatedAt,
      lastMessage: last is Map
          ? ChatPreview(
              id: last['id'] as String? ?? '',
              senderUid: last['senderUid'] as String? ?? '',
              text: last['text'] as String? ?? '',
              unsent: last['unsent'] as bool? ?? false,
              sentAt: updatedAt,
            )
          : null,
      unread: {
        if (data['unread'] case final Map m)
          for (final e in m.entries) e.key as String: (e.value as num).toInt(),
      },
      readAt: marks(data['readAt']),
      deliveredAt: marks(data['deliveredAt']),
      typing: marks(data['typing']),
    );
  }

  ChatMessage _messageFrom(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final sentAt = data['sentAt'];
    return ChatMessage(
      id: doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      sentAt: sentAt is Timestamp ? sentAt.toDate() : DateTime.now(),
      unsent: data['unsent'] as bool? ?? false,
      pending: doc.metadata.hasPendingWrites,
      cursor: doc,
    );
  }
}

/// Firestore when it is configured; nothing otherwise. See [ChatRepository].
ChatRepository? buildChatRepository() =>
    FirebaseBootstrap.isReady ? ChatRepository() : null;
