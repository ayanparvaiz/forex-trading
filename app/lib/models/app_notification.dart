/// What happened.
///
/// Stored as the enum name, so adding a kind later cannot renumber the ones
/// already written.
enum NotificationKind {
  connectionRequest(
    bn: 'আপনার সাথে কানেক্ট হতে চায়',
    en: 'wants to connect with you',
    emoji: '🤝',
  ),
  connectionAccepted(
    bn: 'আপনার রিকোয়েস্ট গ্রহণ করেছে',
    en: 'accepted your request',
    emoji: '✅',
  ),
  clap(
    bn: 'আপনার পোস্টে রিঅ্যাক্ট করেছে',
    en: 'reacted to your post',
    emoji: '❤️',
  ),
  comment(
    bn: 'আপনার পোস্টে মন্তব্য করেছে',
    en: 'commented on your post',
    emoji: '💬',
  ),
  profileView(
    bn: 'আপনার প্রোফাইল দেখেছে',
    en: 'viewed your profile',
    emoji: '👀',
  );

  const NotificationKind({
    required this.bn,
    required this.en,
    required this.emoji,
  });

  final String bn;
  final String en;
  final String emoji;

  String label(bool bangla) => bangla ? bn : en;

  /// Unknown names fall back rather than throw: a notification written by a
  /// newer build should show as something generic, not crash the list.
  static NotificationKind fromName(String? name) => values.firstWhere(
    (k) => k.name == name,
    orElse: () => NotificationKind.profileView,
  );
}

/// One thing that happened, addressed to one person.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.actorUsername,
    required this.actorName,
    required this.actorAvatarId,
    required this.createdAt,
    required this.read,
    this.postId,
  });

  final String id;
  final NotificationKind kind;

  /// Who did it. The username is the stable reference; name and avatar are
  /// copied in so the list renders without a read per row.
  final String actorUsername;
  final String actorName;
  final int actorAvatarId;

  final DateTime createdAt;
  final bool read;

  /// Set for post reactions, so tapping through can open the right post.
  final String? postId;

  /// How long a notification stays before it disappears on its own.
  ///
  /// Short on purpose. This is a feed of what just happened, not an archive —
  /// anything older is noise, and expiring it in the query means nobody has to
  /// clean up after it.
  static const lifetime = Duration(hours: 48);

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    kind: kind,
    actorUsername: actorUsername,
    actorName: actorName,
    actorAvatarId: actorAvatarId,
    createdAt: createdAt,
    read: read ?? this.read,
    postId: postId,
  );
}
