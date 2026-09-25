import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/session_controller.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import 'community_screen.dart';

/// Opens one post — from a chat it was shared into, say.
Future<void> openPost(BuildContext context, String postId) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => PostScreen(postId: postId)));

/// A single post, as the feed shows it: likes, comments, and — if it is
/// yours — delete. One that has been deleted says so.
class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.postId});

  final String postId;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  CommunityRepository? _repository;
  Future<FeedPost?>? _post;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repository != null) return;
    final session = context.session;
    final repository = buildCommunityRepository(
      session.language,
      viewerUid: session.uid,
    );
    _repository = repository;
    _post = repository.post(widget.postId).catchError((Object e) {
      debugPrint('post ${widget.postId} failed: $e');
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.sharedPost)),
      body: FutureBuilder<FeedPost?>(
        future: _post,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.brand,
              ),
            );
          }
          final post = snapshot.data;
          if (post == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hide_source_rounded,
                      size: 36,
                      color: AppColors.textMuted,
                    ),
                    Gap.h12,
                    Text(
                      s.postUnavailable,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(Gap.lg),
            children: [
              FeedCard(
                post: post,
                s: s,
                repository: _repository!,
                // Deleted from here: nothing left to look at.
                onDeleted: (_) => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      ),
    );
  }
}
