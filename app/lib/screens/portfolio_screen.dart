import 'package:flutter/material.dart';

import '../core/calculations.dart';
import '../data/account_scope.dart';
import '../data/account_store.dart';
import '../data/avatars.dart';
import '../data/firestore_community_repository.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

/// Home screen: what the account is worth, and how well it is being run.
///
/// The discipline ring is the largest element on the page and the points sit
/// under it. That ordering is the product argument — rank the habit, not the
/// outcome — expressed as layout.
class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    final session = context.session;
    final s = context.s;
    final stats = store.stats;
    final discipline = store.discipline;
    final profile = session.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navPortfolio),
        actions: [
          Pill(
            text: '${store.badge.tier.emoji} ${store.badge.label(s.isBangla)}',
            color: AppColors.warning,
          ),
          Gap.w8,
          if (profile != null)
            _ProfileButton(avatarId: profile.avatarId, name: profile.displayName),
          Gap.w8,
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          _EquityCard(store: store, stats: stats, s: s),
          Gap.h12,
          _DisciplineCard(discipline: discipline, s: s),
          Gap.h12,
          _BadgeCard(store: store, s: s),
          Gap.h12,
          _StatsCard(stats: stats, s: s),
          Gap.h12,
          _OpenPositions(store: store, s: s),
        ],
      ),
    );
  }
}

/// Avatar in the app bar. Tapping it opens language and sign-out.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.avatarId, required this.name});

  final int avatarId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSheet(context),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.elevated,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          Avatars.byId(avatarId).emoji,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) {
    final session = context.session;
    final s = context.s;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    Avatars.byId(avatarId).emoji,
                    style: const TextStyle(fontSize: 34),
                  ),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '@${session.profile?.username ?? ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Gap.h24,
              Text(s.chooseLanguage,
                  style: Theme.of(sheetContext).textTheme.labelSmall),
              Gap.h8,
              Row(
                children: [
                  for (final language in AppLanguage.values) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          session.setLanguage(language);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: Gap.md),
                          decoration: BoxDecoration(
                            color: session.language == language
                                ? AppColors.brandDim
                                : AppColors.elevated,
                            borderRadius: Radii.tile,
                            border: Border.all(
                              color: session.language == language
                                  ? AppColors.brand
                                  : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${language.flag}  ${language.nativeName}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (language != AppLanguage.values.last) Gap.w12,
                  ],
                ],
              ),
              Gap.h16,
              FilledButton.icon(
                onPressed: () {
                  final username = session.profile?.username;
                  Navigator.of(sheetContext).pop();
                  if (username == null) return;
                  openProfile(
                    context,
                    username,
                    buildCommunityRepository(session.language),
                  );
                },
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(s.profile),
              ),
              Gap.h8,
              TextButton.icon(
                onPressed: () {
                  session.logOut();
                  Navigator.of(sheetContext).pop();
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(s.logOut),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.loss,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquityCard extends StatelessWidget {
  const _EquityCard({required this.store, required this.stats, required this.s});

  final AccountStore store;
  final TradeStats stats;
  final Strings s;

  /// `3ঘ 12মি` — how long is left before the allowance resets.
  String _formatCountdown(Duration d, bool bangla) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return bangla ? '$hoursঘ $minutesমি' : '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final equity = store.equity;
    final openPnl = store.openPnl;
    final growth = store.todaysPnl;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.todaysPoints,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              Pill(
                text: s.resetsIn(
                  _formatCountdown(store.untilReset, s.isBangla),
                ),
                color: AppColors.textMuted,
                icon: Icons.schedule,
                dense: true,
              ),
            ],
          ),
          Gap.h4,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                pointsValue(equity),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.1,
                  fontFeatures: tabularFigures,
                ),
              ),
              Gap.w8,
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Pill(
                  text: pointsDelta(growth),
                  color: AppColors.forValue(growth),
                ),
              ),
            ],
          ),
          Gap.h12,
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: s.balance,
                  value: pointsValue(store.balance),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.openPnl,
                  value: pointsDelta(openPnl),
                  valueColor: AppColors.forValue(openPnl),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.totalR,
                  value: rMultiple(stats.totalR),
                  valueColor: AppColors.forValue(stats.totalR),
                ),
              ),
            ],
          ),
          if (stats.equityCurve.length > 1) ...[
            Gap.h16,
            Sparkline(values: stats.equityCurve),
          ],
        ],
      ),
    );
  }
}

class _DisciplineCard extends StatelessWidget {
  const _DisciplineCard({required this.discipline, required this.s});

  final DisciplineBreakdown discipline;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final worst = discipline.worstFirst;

    return SectionCard(
      title: s.disciplineScore,
      trailing: Pill(
        text: s.rankedOnThis,
        color: AppColors.discipline,
        dense: true,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreRing(
            score: discipline.score,
            grade: s.gradeFor(discipline.score),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worst.isEmpty ? s.noRulesBroken : s.rulesYouBreak,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (worst.isNotEmpty) ...[
                  Gap.h8,
                  for (final entry in worst.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key.label(s.isBangla),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Pill(
                            text: s.timesCount(entry.value),
                            color: AppColors.loss,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The badge ladder: where they sit, and how far to the next rung.
class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.store, required this.s});

  final AccountStore store;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final rank = store.badge;
    final stats = store.stats;
    final next = rank.nextTier;

    return SectionCard(
      title: s.badge,
      trailing: Pill(
        text: '${rank.points} ${s.points}',
        color: AppColors.warning,
        dense: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(rank.tier.emoji, style: const TextStyle(fontSize: 38)),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rank.label(s.isBangla),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      s.winsLosses(stats.wins, stats.losses),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h16,
          ClipRRect(
            borderRadius: Radii.pill,
            child: LinearProgressIndicator(
              value: rank.progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.elevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.warning),
            ),
          ),
          Gap.h8,
          Text(
            // Golden never stops counting, so it gets the level instead of a
            // "next tier" that does not exist.
            next == null
                ? s.pointsToNext(
                    rank.pointsToNext,
                    '${rank.tier.label(s.isBangla)} ${rank.level + 1}',
                  )
                : s.pointsToNext(rank.pointsToNext, next.label(s.isBangla)),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Gap.h12,
          Text(
            s.badgeRule,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.s});

  final TradeStats stats;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) return const SizedBox.shrink();

    final winPct = '${(stats.winRate * 100).toStringAsFixed(0)}%';

    return SectionCard(
      title: s.stats,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: s.expectancy,
                  value: rMultiple(stats.expectancyR),
                  hint: s.perTradeAvg,
                  valueColor: AppColors.forValue(stats.expectancyR),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.winRate,
                  value: winPct,
                  hint: s.tradesOf(stats.wins, stats.total),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.maxDrawdown,
                  value: '${stats.maxDrawdownPercent.toStringAsFixed(1)}%',
                  hint: s.recoverNeeds(
                    '${stats.recoveryNeededPercent.toStringAsFixed(1)}%',
                  ),
                  valueColor: stats.maxDrawdownPercent > 20
                      ? AppColors.loss
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (stats.expectancyR > 0 && stats.winRate < 0.5) ...[
            Gap.h16,
            _Insight(
              icon: Icons.lightbulb_outline,
              color: AppColors.brand,
              text: s.winRateInsight(winPct),
            ),
          ],
        ],
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  const _Insight({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: Radii.tile,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          Gap.w8,
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenPositions extends StatelessWidget {
  const _OpenPositions({required this.store, required this.s});

  final AccountStore store;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final open = store.openTrades;

    return SectionCard(
      title: s.openPositions,
      trailing: Text(
        s.countItems(open.length),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      child: open.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.lg),
              child: Text(
                s.noOpenPositions,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            )
          : Column(
              children: [
                for (final trade in open)
                  _OpenPositionRow(trade: trade, store: store, s: s),
              ],
            ),
    );
  }
}

class _OpenPositionRow extends StatelessWidget {
  const _OpenPositionRow({
    required this.trade,
    required this.store,
    required this.s,
  });

  final Trade trade;
  final AccountStore store;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final price = store.market.price(trade.instrument);
    final pnl = trade.netPnlAt(price);
    final r = trade.rMultipleAt(price);
    final isLong = trade.direction == TradeDirection.buy;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isLong ? AppColors.profitDim : AppColors.lossDim,
              borderRadius: Radii.tile,
            ),
            child: Icon(
              isLong ? Icons.trending_up : Icons.trending_down,
              size: 18,
              color: isLong ? AppColors.profit : AppColors.loss,
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trade.symbol,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${isLong ? s.buy : s.sell} · '
                  '${trade.lots.toStringAsFixed(2)} ${s.lots} · '
                  '${trade.instrument.formatPrice(trade.entryPrice)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rMultiple(r),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: tabularFigures,
                  color: AppColors.forValue(r),
                ),
              ),
              Text(
                pointsDelta(pnl),
                style: TextStyle(
                  fontSize: 11.5,
                  fontFeatures: tabularFigures,
                  color: AppColors.forValue(pnl),
                ),
              ),
            ],
          ),
          Gap.w8,
          IconButton(
            onPressed: () => store.closeTrade(trade.id),
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textMuted,
            tooltip: s.closePosition,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
