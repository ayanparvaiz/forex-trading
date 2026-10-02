import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/community_repository.dart';
import '../data/notification_repository.dart';
import '../data/safety_repository.dart';
import '../data/session_controller.dart';
import '../models/app_notification.dart';
import '../models/post_comment.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_image.dart';
import '../widgets/common.dart';
import '../widgets/report_sheet.dart';
import 'profile_screen.dart';

/// Opens the comment thread for a post. On a question, [pickBest] for the
/// one who asked it, who picks the best answer — [answerId], once picked.
Future<void> showPostComments(
  BuildContext context, {
  required String postId,
  required CommunityRepository repository,
  bool pickBest = false,
  String? answerId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CommentsSheet(
      postId: postId,
      repository: repository,
      pickBest: pickBest,
      answerId: answerId,
    ),
  );
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.postId,
    required this.repository,
    this.pickBest = false,
    this.answerId,
  });

  final String postId;
  final CommunityRepository repository;

  /// On a question, for the one who asked it.
  final bool pickBest;
  final String? answerId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  /// The comment being answered, shown over the box until sent or dropped.
  PostComment? _replyingTo;

  /// On a question, the best answer picked so far.
  late String? _answerId = widget.answerId;

  /// The asker picks the best answer, or takes the pick back — at once,
  /// then written.
  Future<void> _pickBest(PostComment c) async {
    final before = _answerId;
    final next = before == c.id ? null : c.id;
    setState(() => _answerId = next);
    try {
      await widget.repository.setBestAnswer(widget.postId, next);
    } catch (e) {
      debugPrint('best answer failed: $e');
      if (!mounted) return;
      setState(() => _answerId = before);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.s.couldNotSave)));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _replyTo(PostComment c) {
    setState(() => _replyingTo = c);
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    final session = context.session;
    final me = session.profile;
    final uid = session.uid;
    if (body.isEmpty || me == null || uid == null) return;

    final answering = _replyingTo;
    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    // Cleared before the write lands, so the thread feels immediate. The live
    // stream puts the comment on screen a moment later.
    _controller.clear();

    await widget.repository.addComment(
      postId: widget.postId,
      uid: uid,
      username: me.username,
      name: me.displayName,
      avatarId: me.avatarId,
      body: body,
      replyTo: answering == null
          ? null
          : CommentReply(
              id: answering.id,
              authorUid: answering.authorUid,
              name: answering.authorName,
            ),
    );

    // Telling the author is a courtesy, and it must not hold up the comment.
    final authorUid = await widget.repository.postAuthorUid(widget.postId);
    if (authorUid != null) {
      await notificationRepository.notify(
        recipientUid: authorUid,
        kind: NotificationKind.comment,
        actorUid: uid,
        actorUsername: me.username,
        actorName: me.displayName,
        actorAvatarId: me.avatarId,
        postId: widget.postId,
      );
    }

    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md,
                Gap.lg,
                Gap.sm,
              ),
              child: Row(
                children: [
                  Text(
                    s.comments,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<PostComment>>(
                stream: widget.repository.watchComments(widget.postId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.brand,
                      ),
                    );
                  }

                  // Nothing from anyone you have blocked.
                  final blocked =
                      InboxScope.of(context)?.blockedUsernames ?? const {};
                  final comments = [
                    for (final c in snapshot.data!)
                      if (!blocked.contains(c.authorUsername)) c,
                  ];
                  if (comments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.noComments,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13.5,
                              ),
                            ),
                            Gap.h8,
                            Text(
                              s.commentGuideline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Replies under the comment they answer.
                  final thread = threadComments(comments);
                  final me = context.session.uid;
                  final asking = me != null && widget.pickBest;
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(Gap.lg),
                    itemCount: thread.length,
                    itemBuilder: (context, i) {
                      final c = thread[i].$1;
                      return _CommentRow(
                        comment: c,
                        isReply: thread[i].$2,
                        postId: widget.postId,
                        repository: widget.repository,
                        onReply: () => _replyTo(c),
                        best: _answerId == c.id,
                        // Who asked picks among the others' answers.
                        onPickBest: asking && c.authorUid != me
                            ? () => _pickBest(c)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            if (_replyingTo case final r?)
              Container(
                color: AppColors.elevated,
                padding: const EdgeInsets.fromLTRB(Gap.lg, 6, Gap.xs, 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply_rounded,
                      size: 16,
                      color: AppColors.brand,
                    ),
                    Gap.w8,
                    Expanded(
                      child: Text(
                        s.replyingTo(r.authorName),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _replyingTo = null),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.sm,
                  Gap.lg,
                  Gap.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: _focus,
                        controller: _controller,
                        maxLength: PostComment.maxLength,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                        decoration: InputDecoration(
                          hintText: s.writeComment,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    Gap.w8,
                    IconButton.filled(
                      onPressed: _controller.text.trim().isEmpty || _sending
                          ? null
                          : _send,
                      icon: const Icon(Icons.send_rounded, size: 19),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.elevated,
                      ),
                      tooltip: s.send,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.postId,
    required this.repository,
    required this.onReply,
    this.isReply = false,
    this.best = false,
    this.onPickBest,
  });

  final PostComment comment;
  final String postId;
  final CommunityRepository repository;
  final VoidCallback onReply;

  /// Picked as the question's best answer.
  final bool best;

  /// Set for whoever asked: picking this one, or taking the pick back.
  final VoidCallback? onPickBest;

  /// Drawn indented, under the comment it answers.
  final bool isReply;

  Future<void> _like(BuildContext context, bool like) async {
    final uid = context.session.uid;
    if (uid == null) return;
    try {
      await repository.likeComment(
        postId: postId,
        commentId: comment.id,
        uid: uid,
        like: like,
      );
    } catch (e) {
      debugPrint('comment like failed: $e');
    }
  }

  /// Long-pressing someone else's comment offers to report it, quoted exactly.
  bool _reportable(BuildContext context) =>
      comment.authorUid.isNotEmpty &&
      comment.authorUid != context.session.uid &&
      InboxScope.read(context)?.safety != null;

  Future<void> _actions(BuildContext context) async {
    final s = context.s;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined, color: AppColors.loss),
          title: Text(s.report, style: const TextStyle(color: AppColors.loss)),
          onTap: () => Navigator.of(sheet).pop('report'),
        ),
      ),
    );
    if (action != 'report' || !context.mounted) return;
    await showReportSheet(
      context,
      ReportTarget.comment(
        targetUid: comment.authorUid,
        targetUsername: comment.authorUsername,
        postId: postId,
        commentId: comment.id,
        quote: comment.body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    final uid = context.session.uid;
    final liked = uid != null && comment.likedBy.contains(uid);
    final likes = comment.likedBy.length;

    return GestureDetector(
      onLongPress: _reportable(context) ? () => _actions(context) : null,
      child: Padding(
        padding: EdgeInsets.only(bottom: Gap.md, left: isReply ? 44 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () =>
                  openProfile(context, comment.authorUsername, repository),
              child: AvatarImage(
                comment.authorAvatarId,
                size: isReply ? 26 : 34,
              ),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.authorName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Gap.w8,
                      Text(
                        s.timeAgo(comment.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (best) ...[
                    Gap.h4,
                    Pill(
                      text: s.bestAnswer,
                      icon: Icons.check_circle_rounded,
                      color: AppColors.profit,
                      dense: true,
                    ),
                  ],
                  Gap.h4,
                  Text.rich(
                    TextSpan(
                      children: [
                        // A reply to a reply says whom it answers.
                        if (isReply && comment.replyTo != null)
                          TextSpan(
                            text: '@${comment.replyTo!.name} ',
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        TextSpan(text: comment.body),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13.5, height: 1.45),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onReply,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.textMuted,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(s.reply),
                      ),
                      Gap.w12,
                      InkWell(
                        onTap: uid == null
                            ? null
                            : () => _like(context, !liked),
                        borderRadius: Radii.pill,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                liked ? Icons.favorite : Icons.favorite_border,
                                size: 14,
                                color: liked
                                    ? AppColors.loss
                                    : AppColors.textMuted,
                              ),
                              if (likes > 0) ...[
                                Gap.w4,
                                Text(
                                  '$likes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: liked
                                        ? AppColors.loss
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (onPickBest != null) ...[
                        Gap.w12,
                        Flexible(
                          child: TextButton.icon(
                            onPressed: onPickBest,
                            icon: Icon(
                              best
                                  ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 15,
                            ),
                            label: Text(
                              best ? s.unmarkBestAnswer : s.markBestAnswer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppColors.profit,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
