import 'package:flutter/material.dart';

import '../core/calculations.dart';
import '../data/account_scope.dart';
import '../data/account_store.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Trade history and the numbers derived from it.
///
/// Results are stated in R first and dollars second, everywhere. A beginner who
/// learns to think "that was a −1R day" instead of "I lost twelve dollars" has
/// learned most of what this app exists to teach.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    final stats = store.stats;
    final closed = store.closedTrades;

    return Scaffold(
      appBar: AppBar(title: const Text('জার্নাল')),
      body: closed.isEmpty
          ? const _EmptyJournal()
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
              children: [
                _PerformanceCard(stats: stats),
                Gap.h12,
                _DrawdownCard(stats: stats),
                Gap.h12,
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: Gap.sm),
                  child: Text(
                    'বন্ধ হওয়া ট্রেড',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final trade in closed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: _TradeCard(trade: trade, store: store),
                  ),
              ],
            ),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Gap.xl),
        child: Text(
          'এখনো কোনো ট্রেড বন্ধ হয়নি।\n\n'
          'জার্নাল ছাড়া ট্রেডিং হলো অন্ধকারে গুলি ছোড়া —\n'
          'কোনটা লাগল আর কোনটা লাগল না, কিছুই জানবেন না।',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.6),
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.stats});

  final TradeStats stats;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'পারফরম্যান্স',
      child: Column(
        children: [
          Sparkline(values: stats.equityCurve, height: 64),
          Gap.h16,
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'এক্সপেক্টেন্সি',
                  value: rMultiple(stats.expectancyR),
                  hint: 'প্রতি ট্রেডে',
                  valueColor: AppColors.forValue(stats.expectancyR),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'প্রফিট ফ্যাক্টর',
                  value: stats.profitFactor.isFinite
                      ? stats.profitFactor.toStringAsFixed(2)
                      : '∞',
                  hint: '১.০ এর উপরে ভালো',
                  valueColor: AppColors.forValue(stats.profitFactor - 1),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'মোট',
                  value: money(stats.netPnl),
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
                  label: 'গড় জয়',
                  value: rMultiple(stats.avgWinR),
                  hint: '${stats.wins}টি ট্রেড',
                  valueColor: AppColors.profit,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'গড় পরাজয়',
                  value: rMultiple(-stats.avgLossR),
                  hint: '${stats.losses}টি ট্রেড',
                  valueColor: AppColors.loss,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'উইন রেট',
                  value: '${(stats.winRate * 100).toStringAsFixed(0)}%',
                  hint: 'কম হলেও চলে',
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
  const _DrawdownCard({required this.stats});

  final TradeStats stats;

  @override
  Widget build(BuildContext context) {
    final dd = stats.maxDrawdownPercent;
    final recovery = stats.recoveryNeededPercent;

    return SectionCard(
      title: 'ড্রডাউন ও ফেরার অঙ্ক',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'সর্বোচ্চ ড্রডাউন',
                  value: '${dd.toStringAsFixed(1)}%',
                  valueColor: dd > 20 ? AppColors.loss : AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'ফিরতে লাগবে',
                  value: recovery.isFinite
                      ? '${recovery.toStringAsFixed(1)}%'
                      : '∞',
                  valueColor: AppColors.warning,
                ),
              ),
            ],
          ),
          Gap.h16,
          const Text(
            'লস আর লাভের অঙ্ক সমান না:',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          Gap.h8,
          for (final loss in [10.0, 25.0, 50.0, 90.0])
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      '${loss.toStringAsFixed(0)}% হারালে',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_right_alt,
                      size: 15, color: AppColors.textMuted),
                  Gap.w8,
                  Text(
                    'ফিরতে লাগবে ${recoveryGainFor(loss).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: tabularFigures,
                      color: loss >= 50 ? AppColors.loss : AppColors.warning,
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
  const _TradeCard({required this.trade, required this.store});

  final Trade trade;
  final AccountStore store;

  @override
  Widget build(BuildContext context) {
    final r = trade.rMultiple ?? 0;
    final pnl = trade.realisedPnl ?? 0;

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
                          trade.direction.bn,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: trade.direction == TradeDirection.buy
                                ? AppColors.profit
                                : AppColors.loss,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${money(pnl)} · ${trade.exitReason?.bn ?? ''} · '
                      '${timeAgo(trade.closedAt!)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trade.isShared)
                const Icon(Icons.people_outline,
                    size: 16, color: AppColors.textMuted),
            ],
          ),
          Gap.h12,
          _detailRow('রিস্ক',
              '${trade.riskPips.toStringAsFixed(0)} পিপ · '
              '${trade.riskPercent.toStringAsFixed(2)}%'),
          _detailRow('সাইজ',
              '${trade.lots.toStringAsFixed(2)} লট · R:R ১:'
              '${trade.riskReward.toStringAsFixed(1)}'),
          _detailRow('খরচ',
              'স্প্রেড ${money(-trade.spreadCost)}'
              '${trade.swapCost != 0 ? ' · সোয়াপ ${money(trade.swapCost)}' : ''}'),
          Gap.h12,
          _note('কেন নিয়েছিলাম', trade.reason, AppColors.textSecondary),
          if (trade.lesson != null) ...[
            Gap.h8,
            _note('কী শিখলাম', trade.lesson!, AppColors.brand),
          ],
          if (trade.violations.isNotEmpty) ...[
            Gap.h12,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in trade.violations)
                  Pill(text: v.bn, color: AppColors.loss, dense: true),
              ],
            ),
          ],
          if (trade.lesson == null) ...[
            Gap.h12,
            OutlinedButton.icon(
              onPressed: () => _writeLesson(context),
              icon: const Icon(Icons.edit_note, size: 17),
              label: const Text('কী শিখলেন লিখুন'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(40),
                shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
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
          Text(
            body,
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
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
              'কী শিখলেন?',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            Gap.h4,
            const Text(
              'জিতেছেন না হেরেছেন সেটা না — কোন সিদ্ধান্তটা ঠিক ছিল, কোনটা ভুল।',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            Gap.h16,
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              style: const TextStyle(fontSize: 14, height: 1.4),
              decoration: const InputDecoration(
                hintText: 'যেমন: সেটআপ ঠিক ছিল, কিন্তু স্টপ খুব কাছে দিয়েছিলাম।',
              ),
            ),
            Gap.h16,
            FilledButton(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(controller.text.trim()),
              child: const Text('সেভ করুন'),
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
