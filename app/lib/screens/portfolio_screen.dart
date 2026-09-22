import 'package:flutter/material.dart';

import '../core/calculations.dart';
import '../data/account_scope.dart';
import '../data/account_store.dart';
import '../data/avatars.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Home screen: what the account is worth, and how well it is being run.
///
/// The discipline ring is the largest element on the page and the money sits
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
            text: store.tier.label(s.isBangla),
            color: AppColors.brand,
            icon: Icons.workspace_premium_outlined,
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
          _TierCard(store: store, s: s),
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

  final String avatarId;
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

  @override
  Widget build(BuildContext context) {
    final equity = store.equity;
    final openPnl = store.openPnl;
    final growth = equity - store.startingBalance;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.equityDemo, style: Theme.of(context).textTheme.labelSmall),
          Gap.h4,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$${equity.toStringAsFixed(2)}',
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
                  text: money(growth),
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
                  value: '\$${store.balance.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.openPnl,
                  value: money(openPnl),
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

class _TierCard extends StatelessWidget {
  const _TierCard({required this.store, required this.s});

  final AccountStore store;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final next = store.nextTier;
    if (next == null) return const SizedBox.shrink();

    final done = store.closedTrades.length;
    final score = store.discipline.score;

    return SectionCard(
      title: s.nextTier,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.tierUnlockNote('\$${next.balance.toStringAsFixed(0)}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Gap.h12,
          ClipRRect(
            borderRadius: Radii.pill,
            child: LinearProgressIndicator(
              value: store.tierProgress,
              minHeight: 8,
              backgroundColor: AppColors.elevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.brand),
            ),
          ),
          Gap.h12,
          Row(
            children: [
              Expanded(
                child: _Requirement(
                  label: s.trades,
                  value: '$done / ${next.tradesRequired}',
                  met: done >= next.tradesRequired,
                ),
              ),
              Expanded(
                child: _Requirement(
                  label: s.discipline,
                  value: '${score.toStringAsFixed(0)} / '
                      '${next.disciplineRequired.toStringAsFixed(0)}',
                  met: score >= next.disciplineRequired,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.label,
    required this.value,
    required this.met,
  });

  final String label;
  final String value;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: met ? AppColors.profit : AppColors.textMuted,
        ),
        Gap.w8,
        Flexible(
          child: Text(
            '$label  ',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
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
                money(pnl),
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
