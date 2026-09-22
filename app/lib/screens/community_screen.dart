import 'package:flutter/material.dart';

import '../data/mock_community.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Leaderboard and shared journal feed.
///
/// The leaderboard ranks on discipline, and shows total R beside it without
/// ranking on it. The top trader in the sample data is down on the year; the
/// most profitable one is fourth. That contrast is the lesson, and it is why
/// the ranking rule is stated in plain text at the top of the list rather than
/// left for anyone to infer.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('কমিউনিটি'),
          bottom: const TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.brand,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: AppColors.border,
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'লিডারবোর্ড'),
              Tab(text: 'ফিড'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_Leaderboard(), _Feed()],
        ),
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard();

  @override
  Widget build(BuildContext context) {
    final traders = MockCommunity.leaderboard;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: AppColors.disciplineDim,
            borderRadius: Radii.tile,
            border: Border.all(
              color: AppColors.discipline.withValues(alpha: 0.4),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined,
                  size: 18, color: AppColors.discipline),
              Gap.w12,
              Expanded(
                child: Text(
                  'এই তালিকা লাভ দিয়ে সাজানো না — ডিসিপ্লিন দিয়ে সাজানো।\n'
                  'কে নিয়ম মেনেছে সেটাই র‍্যাংক ঠিক করে। লাভ দিয়ে র‍্যাংক করলে '
                  'এই অ্যাপটা ক্যাসিনো হয়ে যেত।',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Gap.h16,
        for (var i = 0; i < traders.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: _LeaderboardRow(rank: i + 1, trader: traders[i]),
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.trader});

  final int rank;
  final Trader trader;

  Color get _scoreColor {
    if (trader.disciplineScore >= 75) return AppColors.discipline;
    if (trader.disciplineScore >= 50) return AppColors.warning;
    return AppColors.loss;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                color: rank <= 3 ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          Text(trader.avatarEmoji, style: const TextStyle(fontSize: 22)),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trader.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap.h4,
                Row(
                  children: [
                    Text(
                      '${trader.tradeCount} ট্রেড',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const Text(' · ',
                        style: TextStyle(color: AppColors.textMuted)),
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
                      const Text(' · ',
                          style: TextStyle(color: AppColors.textMuted)),
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
                trader.disciplineGrade,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed();

  @override
  Widget build(BuildContext context) {
    final posts = MockCommunity.feed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        for (final post in posts)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: _FeedCard(post: post),
          ),
      ],
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(post.author.avatarEmoji, style: const TextStyle(fontSize: 26)),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${post.symbol} · ${timeAgo(post.postedAt)}',
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
                const Text(
                  'কেন নিয়েছিলাম',
                  style: TextStyle(
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
                  'কী শিখলাম',
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
                text: post.followedRules ? 'নিয়ম মেনেছে' : 'নিয়ম ভেঙেছে',
                color: post.followedRules ? AppColors.profit : AppColors.loss,
                icon: post.followedRules
                    ? Icons.verified_outlined
                    : Icons.error_outline,
                dense: true,
              ),
              const Spacer(),
              const Icon(Icons.favorite_border,
                  size: 16, color: AppColors.textMuted),
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
              const Icon(Icons.mode_comment_outlined,
                  size: 15, color: AppColors.textMuted),
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
