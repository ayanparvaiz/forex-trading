/// One comment on a shared journal entry.
class PostComment {
  const PostComment({
    required this.id,
    required this.authorUsername,
    required this.authorName,
    required this.authorAvatarId,
    required this.body,
    required this.createdAt,
    this.authorUid = '',
  });

  final String id;

  /// The author's account id — what a report about this comment points at.
  final String authorUid;

  /// Author details are copied in rather than joined, so drawing a thread costs
  /// one query instead of one query plus a read per comment.
  final String authorUsername;
  final String authorName;
  final int authorAvatarId;

  final String body;
  final DateTime createdAt;

  static const maxLength = 1000;
}

/// The numbers on a post that other people move.
///
/// Streamed separately from the post itself: the text never changes, but these
/// do, and a card should update its counts without refetching the page it
/// lives on.
class PostCounters {
  const PostCounters({
    required this.claps,
    required this.commentCount,
    required this.reach,
  });

  final int claps;
  final int commentCount;

  /// How many people have seen it. Streamed with the rest because opening the
  /// card is itself a view — a reach that only updated on reload would be
  /// wrong the instant it was drawn.
  final int reach;
}
