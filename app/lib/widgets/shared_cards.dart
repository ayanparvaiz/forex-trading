import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import 'avatar_image.dart';
import 'common.dart';

/// A feed post shared into a conversation: who wrote it, what it was about,
/// the lesson, and a way into it.
///
/// Shows the post as it is now — [post] is fetched, not copied — so one that
/// has been deleted says so rather than living on in a chat.
class SharedPostCard extends StatelessWidget {
  const SharedPostCard({
    super.key,
    required this.post,
    required this.loading,
    required this.s,
    this.onTap,
  });

  final FeedPost? post;
  final bool loading;
  final Strings s;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = post;
    return GestureDetector(
      onTap: p == null ? null : onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: p == null
            ? Row(
                children: [
                  Icon(
                    loading
                        ? Icons.article_outlined
                        : Icons.hide_source_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      loading ? '…' : s.postUnavailable,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      AvatarImage(p.author.avatarId, size: 26),
                      Gap.w8,
                      Expanded(
                        child: Text(
                          p.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (p.kind == PostKind.rank)
                        Text(
                          '#${p.rank}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.discipline,
                          ),
                        )
                      else
                        Text(
                          rMultiple(p.rMultiple),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forValue(p.rMultiple),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.kind == PostKind.rank
                        ? '${s.discipline} '
                              '${(p.disciplineScore ?? 0).toStringAsFixed(0)}'
                        : p.symbol,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.lesson,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        s.viewPost,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 17,
                        color: AppColors.brand,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// Someone's place on the leaderboard, shared into a conversation. Tapping
/// it opens their profile.
class SharedRankCard extends StatelessWidget {
  const SharedRankCard({
    super.key,
    required this.rank,
    required this.score,
    required this.name,
    required this.s,
    this.onTap,
  });

  final int rank;
  final double score;
  final String name;
  final Strings s;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.discipline.withValues(alpha: 0.35),
              AppColors.disciplineDim,
            ],
          ),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Row(
          children: [
            Text(
              rank == 1
                  ? '🥇'
                  : rank == 2
                  ? '🥈'
                  : rank == 3
                  ? '🥉'
                  : '🏅',
              style: const TextStyle(fontSize: 28),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.rankOnBoard(rank),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.discipline} ${score.toStringAsFixed(0)} · $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
