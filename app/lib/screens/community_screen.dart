import 'package:flutter/material.dart';

import '../data/account_scope.dart';
import '../data/avatars.dart';
import '../data/community_repository.dart';
import '../data/page.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/paged_list.dart';
import 'profile_screen.dart';

/// Leaderboard and shared journal feed.
///
/// The leaderboard ranks on discipline, and shows total R beside it without
/// ranking on it. The top trader in the sample data is down on the year; the
/// most profitable one is fourth. That contrast is the lesson, and it is why
/// the ranking rule is stated in plain text at the top of the list rather than
/// left for anyone to infer.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  /// The signed-in trader as a leaderboard row, built from their live numbers.
  Trader? _you(BuildContext context) {
    final profile = context.session.profile;
    if (profile == null) return null;

    final store = AccountScope.of(context);
    final stats = store.stats;

    return Trader(
      id: profile.username,
      name: profile.displayName,
      avatarEmoji: Avatars.byId(profile.avatarId).emoji,
      disciplineScore: store.discipline.score,
      badgePoints: store.badgePoints,
      totalR: stats.totalR,
      tradeCount: stats.total,
      winRate: stats.winRate,
      journalStreak: 0,
      cohort: profile.cohort,
      isYou: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final language = context.session.language;

    final repository = LocalCommunityRepository(language: language);
    final you = _you(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.navCommunity),
          bottom: TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.brand,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: AppColors.border,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              Tab(text: s.leaderboard),
              Tab(text: s.feed),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Leaderboard(s: s, repository: repository, you: you),
            _Feed(s: s, repository: repository),
          ],
        ),
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({
    required this.s,
    required this.repository,
    required this.you,
  });

  final Strings s;
  final CommunityRepository repository;
  final Trader? you;

  @override
  Widget build(BuildContext context) {
    return PagedListView<Trader>(
      // Rebuild from scratch when the language changes, since the rows and the
      // cohort labels come back translated.
      key: ValueKey(s.lang),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      pageSize: 10,
      fetch: ({Object? cursor, int limit = 10}) async {
        final page = await repository.leaderboard(cursor: cursor, limit: limit);
        final me = you;
        if (me == null) return page;

        // Swap the signed-in trader's live numbers in wherever their row lands.
        return ResultPage(
          items: [
            for (final t in page.items)
              if (t.id == me.id) me else t,
          ],
          cursor: page.cursor,
          hasMore: page.hasMore,
        );
      },
      header: _RankingExplainer(s: s),
      itemBuilder: (context, trader, index) => _LeaderboardRow(
        rank: index + 1,
        trader: trader,
        s: s,
        repository: repository,
      ),
    );
  }
}

/// Why the list is ordered the way it is, stated rather than left to infer.
class _RankingExplainer extends StatelessWidget {
  const _RankingExplainer({required this.s});

  final Strings s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: AppColors.disciplineDim,
        borderRadius: Radii.tile,
        border: Border.all(color: AppColors.discipline.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 18,
            color: AppColors.discipline,
          ),
          Gap.w12,
          Expanded(
            child: Text(
              s.leaderboardExplainer,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.trader,
    required this.s,
    required this.repository,
  });

  final int rank;
  final Trader trader;
  final Strings s;
  final CommunityRepository repository;

  Color get _scoreColor {
    if (trader.disciplineScore >= 75) return AppColors.discipline;
    if (trader.disciplineScore >= 50) return AppColors.warning;
    return AppColors.loss;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openProfile(context, trader.id, repository),
      borderRadius: Radii.tile,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          color: trader.isYou ? AppColors.brandDim : AppColors.surface,
          borderRadius: Radii.tile,
          border: Border.all(
            color: trader.isYou ? AppColors.brand : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: tabularFigures,
                  color: rank <= 3
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
            Text(trader.avatarEmoji, style: const TextStyle(fontSize: 22)),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          trader.isYou ? s.you : trader.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Gap.w4,
                      Text(
                        '${trader.badge.tier.emoji}'
                        '${trader.badge.tier.isTop ? trader.badge.level : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  Gap.h4,
                  Row(
                    children: [
                      Text(
                        s.tradeCount(trader.tradeCount),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Text(
                        ' · ',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      // Profit is shown, never ranked on.
                      Text(
                        rMultiple(trader.totalR),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFeatures: tabularFigures,
                          color: AppColors.forValue(trader.totalR),
                        ),
                      ),
                      if (trader.journalStreak > 0) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        Text(
                          '🔥${trader.journalStreak}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trader.disciplineScore.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    fontFeatures: tabularFigures,
                    color: _scoreColor,
                  ),
                ),
                Text(
                  s.gradeFor(trader.disciplineScore),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed({required this.s, required this.repository});

  final Strings s;
  final CommunityRepository repository;

  @override
  Widget build(BuildContext context) {
    return PagedListView<FeedPost>(
      key: ValueKey(s.lang),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      pageSize: 6,
      fetch: repository.feed,
      itemBuilder: (context, post, _) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.xs),
        child: _FeedCard(post: post, s: s, repository: repository),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.post,
    required this.s,
    required this.repository,
  });

  final FeedPost post;
  final Strings s;
  final CommunityRepository repository;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => openProfile(context, post.author.id, repository),
                child: Text(
                  post.author.avatarEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          openProfile(context, post.author.id, repository),
                      child: Text(
                        post.author.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${post.symbol} · ${s.timeAgo(post.postedAt)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                rMultiple(post.rMultiple),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: tabularFigures,
                  color: AppColors.forValue(post.rMultiple),
                ),
              ),
            ],
          ),
          Gap.h12,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: Radii.tile,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.whyITookIt,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.textMuted,
                  ),
                ),
                Gap.h4,
                Text(
                  post.reason,
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
                Gap.h12,
                Text(
                  s.whatILearned,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: post.followedRules
                        ? AppColors.brand
                        : AppColors.warning,
                  ),
                ),
                Gap.h4,
                Text(
                  post.lesson,
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
          Gap.h12,
          Row(
            children: [
              Pill(
                text: post.followedRules ? s.followedRules : s.brokeRules,
                color: post.followedRules ? AppColors.profit : AppColors.loss,
                icon: post.followedRules
                    ? Icons.verified_outlined
                    : Icons.error_outline,
                dense: true,
              ),
              const Spacer(),
              const Icon(
                Icons.favorite_border,
                size: 16,
                color: AppColors.textMuted,
              ),
              Gap.w4,
              Text(
                '${post.claps}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFeatures: tabularFigures,
                ),
              ),
              Gap.w16,
              const Icon(
                Icons.mode_comment_outlined,
                size: 15,
                color: AppColors.textMuted,
              ),
              Gap.w4,
              Text(
                '${post.commentCount}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
