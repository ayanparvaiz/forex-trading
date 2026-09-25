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
    this.typing = const {},
  });

  final String id;
  final List<String> uids;
  final List<String> users;
  final DateTime updatedAt;
  final ChatPreview? lastMessage;
  final Map<String, int> unread;
  final Map<String, DateTime> readAt;
  final Map<String, DateTime> deliveredAt;

  /// When each person last touched the message box, while they are typing.
  final Map<String, DateTime> typing;

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
    this.senderName,
    this.attachmentType,
  });

  final String id;
  final String senderUid;
  final String text;
  final bool unsent;

  /// In a room, who said it — the list shows "Name: text".
  final String? senderName;

  /// What was shared with it, if anything: "post" or "rank".
  final String? attachmentType;

  /// When the conversation last moved, which is when this was sent.
  final DateTime sentAt;
}

/// A room — a conversation for everyone — as the inbox lists it.
class RoomInfo {
  const RoomInfo({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.updatedAt,
    required this.lastMessage,
  });

  final String id;
  final String name;
  final int memberCount;

  /// When someone last wrote in it.
  final DateTime updatedAt;
  final ChatPreview? lastMessage;
}

/// You, in a room: how far you have read. Absent when you have not joined.
class RoomMembership {
  const RoomMembership({required this.joinedAt, required this.readAt});

  final DateTime joinedAt;
  final DateTime readAt;

  /// Whether anything has been said since you last looked.
  bool behind(RoomInfo room) => room.updatedAt.isAfter(readAt);
}

/// Whether the newest message in [room] is worth a banner.
///
/// Only for members — joining is what asks for them — and only for a
/// message that is new since [beforeId], someone else's, still there, and
/// not in the room you are looking at. Never on the first snapshot, for the
/// same reason as [newArrivals].
bool isRoomArrival({
  required bool first,
  required String? beforeId,
  required RoomInfo room,
  required String me,
  required bool joined,
  required String? openChatId,
}) {
  final last = room.lastMessage;
  return !first &&
      joined &&
      last != null &&
      last.id != beforeId &&
      last.senderUid != me &&
      !last.unsent &&
      openChatId != room.id;
}

/// Something shared into a conversation, beside the words or instead of them.
sealed class MessageAttachment {
  const MessageAttachment();

  /// How it is stored and named in a preview: "post" or "rank".
  String get type;

  Map<String, Object> toJson();

  static MessageAttachment? fromJson(Object? json) {
    if (json is! Map) return null;
    return switch (json['type']) {
      'post' when json['postId'] is String => SharedPost(
        postId: json['postId'] as String,
        authorUid: json['authorUid'] as String? ?? '',
      ),
      'rank' when json['rank'] is num => SharedRank(
        rank: (json['rank'] as num).toInt(),
        score: (json['score'] as num?)?.toDouble() ?? 0,
      ),
      _ => null,
    };
  }
}

/// A feed post. Only which one: the card shows the post as it is now, and
/// says so when it has been deleted.
class SharedPost extends MessageAttachment {
  const SharedPost({required this.postId, required this.authorUid});

  final String postId;
  final String authorUid;

  @override
  String get type => 'post';

  @override
  Map<String, Object> toJson() => {
    'type': type,
    'postId': postId,
    'authorUid': authorUid,
  };
}

/// Where the sender stood on the leaderboard when they shared it.
class SharedRank extends MessageAttachment {
  const SharedRank({required this.rank, required this.score});

  final int rank;
  final double score;

  @override
  String get type => 'rank';

  @override
  Map<String, Object> toJson() => {'type': type, 'rank': rank, 'score': score};
}

/// The message a reply answers: which one, and whose.
///
/// No copy of its text — the original is looked up and shown as it is now,
/// so unsending a message also takes it out of every reply to it.
class ReplyRef {
  const ReplyRef({required this.id, required this.senderUid});

  final String id;
  final String senderUid;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.sentAt,
    required this.unsent,
    required this.pending,
    this.replyTo,
    this.forwarded = false,
    this.senderName,
    this.senderUsername,
    this.attachment,
    this.cursor,
  });

  final String id;
  final String senderUid;
  final String text;
  final DateTime sentAt;
  final bool unsent;

  /// The message this one answers, when it is a reply.
  final ReplyRef? replyTo;

  /// A copy of a message from another conversation.
  final bool forwarded;

  /// In a room, who sent it — copied onto the message when it is sent, since
  /// a room has too many people to look each one up. Null between two people,
  /// where the screen already knows both.
  final String? senderName;
  final String? senderUsername;

  /// A post or a rank shared with it.
  final MessageAttachment? attachment;

  /// Written on this phone but not yet confirmed by the server.
  final bool pending;

  /// Where to continue from when loading older messages. Opaque to
  /// everything but the repository that made it.
  final Object? cursor;
}

/// What one person has deleted from a conversation for themselves only.
///
/// The conversation is untouched — the other person keeps every message.
/// This is just what to leave out on this person's side.
class ChatPrefs {
  const ChatPrefs({this.clearedAt, this.hidden = const {}, this.mutedUntil});

  static const none = ChatPrefs();

  /// "Delete chat": everything sent up to this moment is gone for them.
  final DateTime? clearedAt;

  /// "Delete for me": messages removed one at a time.
  final Set<String> hidden;

  /// Muted until then: no banner for new messages, and not counted on the
  /// Messages tab. Past it, the mute has simply run out.
  final DateTime? mutedUntil;

  /// What "Always" is stored as: the last year a Firestore timestamp holds.
  static final forever = DateTime.utc(9999);

  bool mutedAt(DateTime now) {
    final until = mutedUntil;
    return until != null && until.isAfter(now);
  }

  bool get mutedForever => (mutedUntil?.year ?? 0) >= forever.year;

  /// Whether [m] is shown. A message still on its way is always new, so
  /// never before a clear.
  bool shows(ChatMessage m) {
    if (hidden.contains(m.id)) return false;
    final cleared = clearedAt;
    return cleared == null || m.pending || m.sentAt.isAfter(cleared);
  }

  /// Whether the conversation stays in the inbox. A deleted chat leaves it
  /// until someone says something new.
  bool listsThread(ChatThread t) {
    final cleared = clearedAt;
    return cleared == null || t.updatedAt.isAfter(cleared);
  }

  /// Whether messages sent at [t] and before are all cleared, so there is
  /// nothing older worth loading.
  bool clearedBy(DateTime t) {
    final cleared = clearedAt;
    return cleared != null && !t.isAfter(cleared);
  }
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

/// How long a typing mark counts for.
///
/// The typist refreshes it every few seconds while they type, and removes it
/// when they send or clear the box. This is the backstop for the case where
/// they simply stop — put the phone down mid-sentence — so "typing…" does not
/// stay on forever. Wide enough to survive a refresh arriving a little late.
const typingWindow = Duration(seconds: 8);

/// How often a typist re-stamps their mark while still typing.
const typingRefresh = Duration(seconds: 3);

/// Whether [uid] is typing in [thread] right now.
bool isTyping(ChatThread thread, String uid, DateTime now) {
  final at = thread.typing[uid];
  if (at == null) return false;
  final age = now.difference(at);
  // A mark slightly in the future is a clock a second ahead, not a bug.
  return age <= typingWindow && age >= const Duration(seconds: -5);
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
