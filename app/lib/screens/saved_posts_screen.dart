import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/session_controller.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import 'community_screen.dart';

/// Opens the posts kept for later.
Future<void> openSavedPosts(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SavedPostsScreen()));

/// Posts kept for later, the latest saved first. Pull down to see any saved
/// or forgotten since.
class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  CommunityRepository? _repository;
  Future<List<FeedPost>>? _posts;
  final Set<String> _deleted = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repository != null) return;
    final session = context.session;
    _repository = buildCommunityRepository(
      session.language,
      viewerUid: session.uid,
    );
    _load();
  }

  void _load() {
    final uid = context.session.uid;
    _posts = uid == null
        ? Future.value(const [])
        : _repository!.savedPosts(uid);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _posts;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.savedPosts)),
      body: FutureBuilder<List<FeedPost>>(
        future: _posts,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = [
            for (final p in snap.data ?? const <FeedPost>[])
              if (!_deleted.contains(p.id)) p,
          ];
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.brand,
            child: posts.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(Gap.xl),
                    children: [
                      const SizedBox(height: 80),
                      const Icon(
                        Icons.bookmark_border,
                        size: 44,
                        color: AppColors.textMuted,
                      ),
                      Gap.h12,
                      Text(
                        snap.hasError ? s.couldNotLoad : s.noSavedPosts,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.lg,
                      Gap.md,
                      Gap.lg,
                      Gap.xxl,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: Gap.xs),
                      child: FeedCard(
                        post: posts[i],
                        s: s,
                        repository: _repository!,
                        onDeleted: (id) => setState(() => _deleted.add(id)),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
