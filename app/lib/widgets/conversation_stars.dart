import '../data/starred_messages.dart';
import '../models/chat.dart';
import 'conversation_view.dart';

/// Starring in one conversation, kept with the rest of [uid]'s stars.
class ConversationStars implements MessageStars {
  ConversationStars({
    required this.store,
    required this.uid,
    required this.conversationId,
    required this.room,
    this.otherUid,
    this.otherUsername,
  });

  final StarredMessages store;
  final String uid;
  final String conversationId;
  final bool room;
  final String? otherUid;
  final String? otherUsername;

  @override
  Stream<Set<String>> watch() => store.watchIn(uid, conversationId);

  @override
  Future<void> star(ChatMessage m) => store.star(
    uid,
    conversationId: conversationId,
    messageId: m.id,
    room: room,
    otherUid: otherUid,
    otherUsername: otherUsername,
  );

  @override
  Future<void> unstar(ChatMessage m) => store.unstar(uid, conversationId, m.id);
}
