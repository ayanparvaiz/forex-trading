import 'package:flutter/material.dart';

import '../core/calculations.dart';
import '../data/account_scope.dart';
import '../data/account_store.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/trade.dart';
import '../data/firestore_community_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'post_composer_sheet.dart';

/// Trade history and the numbers derived from it.
///
/// Results are stated in R first and points second, everywhere. A beginner who
/// learns to think "that was a −1R day" instead of "I lost twelve points" has
/// learned most of what this app exists to teach.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    final s = context.s;
    final stats = store.stats;
    final closed = store.closedTrades;

    return Scaffold(
      appBar: AppBar(title: Text(s.navJournal)),
      body: closed.isEmpty
          ? _EmptyJournal(s: s)
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md,
                Gap.lg,
                Gap.xxl,
              ),
              children: [
                _PerformanceCard(stats: stats, s: s),
                Gap.h12,
                _DrawdownCard(stats: stats, s: s),
                Gap.h12,
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: Gap.sm),
                  child: Text(
                    s.closedTrades,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final trade in closed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: _TradeCard(trade: trade, store: store, s: s),
                  ),
              ],
            ),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal({required this.s});

  final Strings s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Text(
          s.emptyJournal,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.stats, required this.s});

  final TradeStats stats;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: s.performance,
      child: Column(
        children: [
          Sparkline(values: stats.equityCurve, height: 64),
          Gap.h16,
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
                  label: s.profitFactor,
                  value: stats.profitFactor.isFinite
                      ? stats.profitFactor.toStringAsFixed(2)
                      : '∞',
                  hint: s.aboveOneGood,
                  valueColor: AppColors.forValue(stats.profitFactor - 1),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.total,
                  value: pointsDelta(stats.netPnl),
                  hint: rMultiple(stats.totalR),
                  valueColor: AppColors.forValue(stats.netPnl),
                ),
              ),
            ],
          ),
          Gap.h16,
          const Divider(),
          Gap.h16,
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: s.avgWin,
                  value: rMultiple(stats.avgWinR),
                  hint: s.tradeCount(stats.wins),
                  valueColor: AppColors.profit,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.avgLoss,
                  value: rMultiple(-stats.avgLossR),
                  hint: s.tradeCount(stats.losses),
                  valueColor: AppColors.loss,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.winRate,
                  value: '${(stats.winRate * 100).toStringAsFixed(0)}%',
                  hint: s.lowIsFine,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawdownCard extends StatelessWidget {
  const _DrawdownCard({required this.stats, required this.s});

  final TradeStats stats;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final dd = stats.maxDrawdownPercent;
    final recovery = stats.recoveryNeededPercent;

    return SectionCard(
      title: s.drawdownAndRecovery,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: s.maxDrawdownLong,
                  value: '${dd.toStringAsFixed(1)}%',
                  valueColor: dd > 20 ? AppColors.loss : AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.recoveryNeeded,
                  value: recovery.isFinite
                      ? '${recovery.toStringAsFixed(1)}%'
                      : '∞',
                  valueColor: AppColors.warning,
                ),
              ),
            ],
          ),
          Gap.h16,
          Text(
            s.lossAndGainAsymmetry,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          Gap.h8,
          for (final loss in [10.0, 25.0, 50.0, 90.0])
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      s.ifYouLosePct('${loss.toStringAsFixed(0)}%'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_right_alt,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  Gap.w8,
                  Expanded(
                    child: Text(
                      s.needsGainPct(
                        '${recoveryGainFor(loss).toStringAsFixed(0)}%',
                      ),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: tabularFigures,
                        color: loss >= 50 ? AppColors.loss : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  const _TradeCard({required this.trade, required this.store, required this.s});

  final Trade trade;
  final AccountStore store;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final r = trade.rMultiple ?? 0;
    final pnl = trade.realisedPnl ?? 0;
    final isLong = trade.direction == TradeDirection.buy;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: r >= 0 ? AppColors.profitDim : AppColors.lossDim,
                  borderRadius: Radii.tile,
                ),
                child: Text(
                  rMultiple(r),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFeatures: tabularFigures,
                    color: AppColors.forValue(r),
                  ),
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trade.symbol,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Gap.w8,
                        Text(
                          isLong ? s.buy : s.sell,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isLong ? AppColors.profit : AppColors.loss,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${pointsDelta(pnl)} · '
                      '${trade.exitReason?.label(s.isBangla) ?? ''} · '
                      '${s.timeAgo(trade.closedAt!)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trade.isShared)
                const Icon(
                  Icons.people_outline,
                  size: 16,
                  color: AppColors.textMuted,
                ),
            ],
          ),
          Gap.h12,
          _detailRow(
            s.risk,
            '${trade.riskPips.toStringAsFixed(0)} ${s.pips} · '
            '${trade.riskPercent.toStringAsFixed(2)}%',
          ),
          _detailRow(
            s.size,
            '${trade.lots.toStringAsFixed(2)} ${s.lots} · R:R 1:'
            '${trade.riskReward.toStringAsFixed(1)}',
          ),
          _detailRow(
            s.cost,
            '${s.spread} ${pointsDelta(-trade.spreadCost)}'
            '${trade.swapCost != 0 ? ' · ${s.swap} ${pointsDelta(trade.swapCost)}' : ''}',
          ),
          Gap.h12,
          _note(s.whyITookIt, trade.reason, AppColors.textSecondary),
          if (trade.lesson != null) ...[
            Gap.h8,
            _note(s.whatILearned, trade.lesson!, AppColors.brand),
          ],
          if (trade.violations.isNotEmpty) ...[
            Gap.h12,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in trade.violations)
                  Pill(
                    text: v.label(s.isBangla),
                    color: AppColors.loss,
                    dense: true,
                  ),
              ],
            ),
          ],
          Gap.h12,
          Row(
            children: [
              if (trade.lesson == null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _writeLesson(context),
                    icon: const Icon(Icons.edit_note, size: 17),
                    label: Text(s.writeLesson),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      side: const BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(40),
                      shape: const RoundedRectangleBorder(
                        borderRadius: Radii.tile,
                      ),
                    ),
                  ),
                )
              else
                // Sharing needs the lesson, so the two buttons never appear at
                // once: write it first, then it can be shared.
                Expanded(
                  child: trade.isShared
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.check, size: 17),
                          label: Text(s.alreadyShared),
                          style: OutlinedButton.styleFrom(
                            disabledForegroundColor: AppColors.textMuted,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size.fromHeight(40),
                            shape: const RoundedRectangleBorder(
                              borderRadius: Radii.tile,
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _share(context),
                          icon: const Icon(Icons.ios_share, size: 17),
                          label: Text(s.shareToFeed),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brand,
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size.fromHeight(40),
                            shape: const RoundedRectangleBorder(
                              borderRadius: Radii.tile,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontFeatures: tabularFigures,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(String label, String body, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: Radii.tile,
        border: Border(left: BorderSide(color: accent, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: accent,
            ),
          ),
          Gap.h4,
          Text(body, style: const TextStyle(fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }

  /// Publishes this trade to the feed.
  ///
  /// Marked as shared only once the post actually landed, so a failed write
  /// leaves the button where it was rather than claiming something that is not
  /// there.
  Future<void> _share(BuildContext context) async {
    final session = context.session;
    final repository = buildCommunityRepository(
      session.language,
      viewerUid: session.uid,
    );

    final posted = await showPostComposer(
      context,
      repository: repository,
      trade: trade,
    );
    if (posted == null || !context.mounted) return;

    store.shareTrade(trade.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.s.posted)));
  }

  Future<void> _writeLesson(BuildContext context) async {
    final controller = TextEditingController();
    final lesson = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.lg,
          Gap.lg,
          Gap.lg,
          MediaQuery.of(sheetContext).viewInsets.bottom + Gap.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.whatDidYouLearn,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            Gap.h4,
            Text(
              s.lessonPrompt,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            Gap.h16,
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: InputDecoration(hintText: s.lessonHint),
            ),
            Gap.h16,
            FilledButton(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(controller.text.trim()),
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (lesson != null && lesson.isNotEmpty) {
      store.addLesson(trade.id, lesson);
    }
  }
}
