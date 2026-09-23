import 'package:flutter/material.dart';

import '../data/avatars.dart';
import '../data/community_repository.dart';
import '../data/notification_repository.dart';
import '../data/session_controller.dart';
import '../models/app_notification.dart';
import '../models/post_comment.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

/// Opens the comment thread for a post.
Future<void> showPostComments(
  BuildContext context, {
  required String postId,
  required CommunityRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CommentsSheet(postId: postId, repository: repository),
  );
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.postId, required this.repository});

  final String postId;
  final CommunityRepository repository;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    final session = context.session;
    final me = session.profile;
    final uid = session.uid;
    if (body.isEmpty || me == null || uid == null) return;

    setState(() => _sending = true);
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
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
              child: Row(
                children: [
                  Text(s.comments,
                      style: Theme.of(context).textTheme.titleMedium),
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

                  final comments = snapshot.data!;
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

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(Gap.lg),
                    itemCount: comments.length,
                    itemBuilder: (context, i) => _CommentRow(
                      comment: comments[i],
                      repository: widget.repository,
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                      onPressed:
                          _controller.text.trim().isEmpty || _sending
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
  const _CommentRow({required this.comment, required this.repository});

  final PostComment comment;
  final CommunityRepository repository;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                openProfile(context, comment.authorUsername, repository),
            child: Text(
              Avatars.byId(comment.authorAvatarId).emoji,
              style: const TextStyle(fontSize: 22),
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
                Gap.h4,
                Text(
                  comment.body,
                  style: const TextStyle(fontSize: 13.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
