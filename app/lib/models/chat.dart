/// A conversation between two traders, as the inbox lists it.
///
/// The id is the id of the connection between the same two people —
/// "alice-bob", usernames sorted — so a conversation can only exist where a
/// connection does, and one lookup answers whether two people may talk.
class ChatThread {
  const ChatThread({
    required this.id,
    required this.uids,
    required this.users,
    required this.updatedAt,
    required this.lastMessage,
    required this.unread,
    required this.readAt,
    required this.deliveredAt,
  });

  final String id;
  final List<String> uids;
  final List<String> users;
  final DateTime updatedAt;
  final ChatPreview? lastMessage;
  final Map<String, int> unread;
  final Map<String, DateTime> readAt;
  final Map<String, DateTime> deliveredAt;

  String otherUid(String me) => uids.first == me ? uids.last : uids.first;

  /// The other person's username, taken from the id both of them share.
  String otherUsername(String myUsername) =>
      users.first == myUsername ? users.last : users.first;

  int unreadFor(String uid) => unread[uid] ?? 0;
}

/// What the inbox row shows. A copy of the latest message, which the rules
/// require to match the message it points at.
class ChatPreview {
  const ChatPreview({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.unsent,
    required this.sentAt,
  });

  final String id;
  final String senderUid;
  final String text;
  final bool unsent;

  /// When the conversation last moved, which is when this was sent.
  final DateTime sentAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.sentAt,
    required this.unsent,
    required this.pending,
    this.cursor,
  });

  final String id;
  final String senderUid;
  final String text;
  final DateTime sentAt;
  final bool unsent;

  /// Written on this phone but not yet confirmed by the server.
  final bool pending;

  /// Where to continue from when loading older messages. Opaque to
  /// everything but the repository that made it.
  final Object? cursor;
}

/// The tick on a message you sent.
enum MessageStatus {
  /// Still on this phone: a clock.
  pending,

  /// On the server: one grey tick.
  sent,

  /// The other person's app has received it: two grey ticks.
  delivered,

  /// The other person has had the conversation open since: two blue ticks.
  read,
}

/// The tick for [message], judged against the other person's marks.
///
/// Marks, not per-message flags: a message is read if it was sent no later
/// than the moment the other person last had the conversation open. Every
/// message before the mark is read at once, which is what WhatsApp shows too.
MessageStatus statusOf(ChatMessage message, ChatThread thread, String me) {
  if (message.pending) return MessageStatus.pending;

  final other = thread.otherUid(me);
  final read = thread.readAt[other];
  if (read != null && !message.sentAt.isAfter(read)) return MessageStatus.read;

  final delivered = thread.deliveredAt[other];
  if (delivered != null && !message.sentAt.isAfter(delivered)) {
    return MessageStatus.delivered;
  }
  return MessageStatus.sent;
}

/// How recently someone was around, as the chat header and inbox show it.
enum Presence { activeNow, recently, unknown }

/// Presence is a heartbeat every minute while the app is open. Firestore
/// cannot see a dropped connection, so "now" means "within a couple of
/// beats" — generous enough that one missed beat does not flicker someone
/// offline, short enough that closing the app shows within minutes.
const activeNowWindow = Duration(seconds: 150);

Presence presenceOf(DateTime? lastActive, DateTime now) {
  if (lastActive == null) return Presence.unknown;
  return now.difference(lastActive) <= activeNowWindow
      ? Presence.activeNow
      : Presence.recently;
}

/// Merges a fresh snapshot of the newest messages into everything loaded.
///
/// Upsert only. Messages are never deleted — the rules forbid it — so one
/// that drops out of the newest-thirty window has not gone anywhere; it has
/// just become older. Removing it would open a gap between the live window
/// and the pages loaded before it. Newest first, like the list draws them.
List<ChatMessage> mergeMessages(
  List<ChatMessage> loaded,
  List<ChatMessage> fresh,
) {
  final byId = {for (final m in loaded) m.id: m};
  for (final m in fresh) {
    byId[m.id] = m;
  }
  return byId.values.toList()..sort((a, b) {
    final t = b.sentAt.compareTo(a.sentAt);
    return t != 0 ? t : b.id.compareTo(a.id);
  });
}

/// Midnight-to-midnight days, for the separators between messages.
DateTime dayOf(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Conversations whose newest message is new since [before], from someone
/// else, and not in the conversation already open — the ones worth a banner.
///
/// Returns nothing on the first snapshot: opening the app is not the same as
/// a message arriving, and a burst of banners for old messages would be noise.
List<ChatThread> newArrivals({
  required Map<String, String?>? before,
  required List<ChatThread> now,
  required String me,
  required String? openChatId,
}) {
  if (before == null) return const [];
  return [
    for (final t in now)
      if (t.lastMessage != null &&
          t.lastMessage!.senderUid != me &&
          !t.lastMessage!.unsent &&
          t.id != openChatId &&
          before[t.id] != t.lastMessage!.id)
        t,
  ];
}
