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
    this.likedBy = const {},
    this.replyTo,
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

  /// Who liked it.
  final Set<String> likedBy;

  /// The comment this one answers, when it is a reply.
  final CommentReply? replyTo;

  static const maxLength = 1000;
}

/// The comment a reply answers: which, whose, and the name to show.
class CommentReply {
  const CommentReply({
    required this.id,
    required this.authorUid,
    required this.name,
  });

  final String id;
  final String authorUid;
  final String name;
}

/// [comments] as a thread, one level deep: each top-level comment followed
/// by every reply in its thread, oldest first. A reply to a reply goes under
/// the same top comment; a reply whose comment is gone stands on its own.
List<(PostComment, bool)> threadComments(List<PostComment> comments) {
  final byId = {for (final c in comments) c.id: c};
  String rootOf(PostComment c) {
    var at = c;
    final seen = <String>{};
    while (at.replyTo != null &&
        byId.containsKey(at.replyTo!.id) &&
        seen.add(at.id)) {
      at = byId[at.replyTo!.id]!;
    }
    return at.id;
  }

  final replies = <String, List<PostComment>>{};
  final tops = <PostComment>[];
  for (final c in comments) {
    final root = rootOf(c);
    if (root == c.id) {
      tops.add(c);
    } else {
      (replies[root] ??= []).add(c);
    }
  }
  return [
    for (final t in tops) ...[
      (t, false),
      for (final r in replies[t.id] ?? const <PostComment>[]) (r, true),
    ],
  ];
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
