import 'package:flutter/material.dart';

import '../core/calculations.dart';
import '../data/account_scope.dart';
import '../data/account_store.dart';
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
    final stats = store.stats;
    final discipline = store.discipline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('পোর্টফোলিও'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.lg),
            child: Center(
              child: Pill(
                text: store.tier.label,
                color: AppColors.brand,
                icon: Icons.workspace_premium_outlined,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          _EquityCard(store: store, stats: stats),
          Gap.h12,
          _DisciplineCard(discipline: discipline),
          Gap.h12,
          _TierCard(store: store),
          Gap.h12,
          _StatsCard(stats: stats),
          Gap.h12,
          _OpenPositions(store: store),
        ],
      ),
    );
  }
}

class _EquityCard extends StatelessWidget {
  const _EquityCard({required this.store, required this.stats});

  final AccountStore store;
  final TradeStats stats;

  @override
  Widget build(BuildContext context) {
    final equity = store.equity;
    final openPnl = store.openPnl;
    final growth = equity - store.startingBalance;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ইকুইটি (ডেমো)',
              style: Theme.of(context).textTheme.labelSmall),
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
                  label: 'ব্যালেন্স',
                  value: '\$${store.balance.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'চলমান লাভ/লস',
                  value: money(openPnl),
                  valueColor: AppColors.forValue(openPnl),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'মোট R',
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
  const _DisciplineCard({required this.discipline});

  final DisciplineBreakdown discipline;

  @override
  Widget build(BuildContext context) {
    final worst = discipline.worstFirst;

    return SectionCard(
      title: 'ডিসিপ্লিন স্কোর',
      trailing: const Pill(
        text: 'লিডারবোর্ড এটা দিয়েই',
        color: AppColors.discipline,
        dense: true,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreRing(score: discipline.score, grade: discipline.grade),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worst.isEmpty
                      ? 'এখন পর্যন্ত কোনো নিয়ম ভাঙেননি। লাভ-লস যাই হোক, '
                          'এভাবে চললে আপনি টিকে থাকবেন।'
                      : 'যে নিয়মগুলো ভাঙছেন:',
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
                              entry.key.bn,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Pill(
                            text: '${entry.value} বার',
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
  const _TierCard({required this.store});

  final AccountStore store;

  @override
  Widget build(BuildContext context) {
    final next = store.nextTier;
    if (next == null) {
      return const SizedBox.shrink();
    }

    final done = store.closedTrades.length;
    final score = store.discipline.score;
    final scoreReady = score >= next.disciplineRequired;

    return SectionCard(
      title: 'পরের ধাপ আনলক',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\$${next.balance.toStringAsFixed(0)} ব্যালেন্স — লাভ দিয়ে না, '
            'নিয়ম মেনে ট্রেড করে আনলক হয়।',
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
                  label: 'ট্রেড',
                  value: '$done / ${next.tradesRequired}',
                  met: done >= next.tradesRequired,
                ),
              ),
              Expanded(
                child: _Requirement(
                  label: 'ডিসিপ্লিন',
                  value: '${score.toStringAsFixed(0)} / '
                      '${next.disciplineRequired.toStringAsFixed(0)}',
                  met: scoreReady,
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
        Text(
          '$label  ',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
  const _StatsCard({required this.stats});

  final TradeStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: 'পরিসংখ্যান',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'এক্সপেক্টেন্সি',
                  value: rMultiple(stats.expectancyR),
                  hint: 'প্রতি ট্রেডে গড়',
                  valueColor: AppColors.forValue(stats.expectancyR),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'উইন রেট',
                  value: '${(stats.winRate * 100).toStringAsFixed(0)}%',
                  hint: '${stats.wins}/${stats.total} ট্রেড',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'ম্যাক্স ড্রডাউন',
                  value: '${stats.maxDrawdownPercent.toStringAsFixed(1)}%',
                  hint: 'ফিরতে '
                      '${stats.recoveryNeededPercent.toStringAsFixed(1)}%',
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
              text: '${(stats.winRate * 100).toStringAsFixed(0)}% ট্রেডে '
                  'জিতেও আপনি লাভে আছেন — কারণ জেতার সময় বড় জিতছেন। '
                  'উইন রেট না, এক্সপেক্টেন্সিই আসল।',
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
  const _OpenPositions({required this.store});

  final AccountStore store;

  @override
  Widget build(BuildContext context) {
    final open = store.openTrades;

    return SectionCard(
      title: 'খোলা পজিশন',
      trailing: Text(
        '${open.length}টি',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      child: open.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: Gap.lg),
              child: Text(
                'এখন কোনো ট্রেড খোলা নেই।\nসেটআপের জন্য অপেক্ষা করাও একটা সিদ্ধান্ত।',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          : Column(
              children: [
                for (final trade in open) _OpenPositionRow(trade: trade, store: store),
              ],
            ),
    );
  }
}

class _OpenPositionRow extends StatelessWidget {
  const _OpenPositionRow({required this.trade, required this.store});

  final Trade trade;
  final AccountStore store;

  @override
  Widget build(BuildContext context) {
    final price = store.market.price(trade.instrument);
    final pnl = trade.netPnlAt(price);
    final r = trade.rMultipleAt(price);
    final isLong = trade.direction == TradeDirection.buy;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Column(
        children: [
          Row(
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
                      '${trade.direction.bn} · ${trade.lots.toStringAsFixed(2)} লট · '
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
                tooltip: 'বন্ধ করুন',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
