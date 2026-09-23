/// One comment on a shared journal entry.
class PostComment {
  const PostComment({
    required this.id,
    required this.authorUsername,
    required this.authorName,
    required this.authorAvatarId,
    required this.body,
    required this.createdAt,
  });

  final String id;

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
  const PostCounters({required this.claps, required this.commentCount});

  final int claps;
  final int commentCount;
}
