import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../data/trade_checklist_pref.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// What the app knows about the trade about to be placed: its own rules,
/// and what the trader puts at risk.
class TradeChecks {
  const TradeChecks({
    required this.violations,
    required this.riskPoints,
    required this.maxRiskPercent,
    required this.minRiskReward,
    required this.maxTradesPerDay,
  });

  /// The rules it would break, as the ticket already counts them.
  final Set<RuleViolation> violations;

  /// What is lost if the stop is hit, as written: "250".
  final String riskPoints;

  final double maxRiskPercent;
  final double minRiskReward;
  final int maxTradesPerDay;
}

/// The checklist before a trade: the rules the app checked, then three
/// things only the trader can say. True to place it.
///
/// A broken rule does not stop the trade — it costs discipline points, as it
/// always has. Saying the three things is what opens the button: a moment to
/// stop, at the one point where stopping helps.
Future<bool> showTradeChecklist(
  BuildContext context,
  TradeChecks checks, {
  TradeChecklistPref? pref,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TradeChecklistSheet(
        checks: checks,
        pref: pref ?? TradeChecklistPref(),
      ),
    ) ??
    false;

class TradeChecklistSheet extends StatefulWidget {
  const TradeChecklistSheet({
    super.key,
    required this.checks,
    required this.pref,
  });

  final TradeChecks checks;
  final TradeChecklistPref pref;

  @override
  State<TradeChecklistSheet> createState() => _TradeChecklistSheetState();
}

class _TradeChecklistSheetState extends State<TradeChecklistSheet> {
  final _said = [false, false, false];
  bool _askEveryTime = true;

  void _setAsk(bool on) {
    setState(() => _askEveryTime = on);
    widget.pref.set(on);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = widget.checks;
    final bn = s.isBangla;
    String fixed(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

    // The rules worth a look before the trade, each as kept or broken.
    final rules = [
      (RuleViolation.riskTooHigh, s.riskWithinLimit(fixed(c.maxRiskPercent))),
      (RuleViolation.poorRiskReward, s.rewardAtLeast(fixed(c.minRiskReward))),
      (RuleViolation.revengeTrade, s.notAfterALoss),
      (RuleViolation.overtrading, s.withinTradesToday(c.maxTradesPerDay)),
    ];
    final pledges = [
      s.fineLosing(c.riskPoints),
      s.myOwnSetup,
      s.calmNotWinningBack,
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist_rounded, color: AppColors.brand),
                Gap.w8,
                Expanded(
                  child: Text(
                    s.beforeYouTrade,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Gap.h12,
            Text(s.appChecked, style: Theme.of(context).textTheme.labelSmall),
            Gap.h4,
            for (final (rule, kept) in rules)
              _RuleRow(
                text: c.violations.contains(rule) ? rule.label(bn) : kept,
                broken: c.violations.contains(rule),
                penalty: s.pointsPenalty(rule.weight),
              ),
            Gap.h12,
            Text(s.yourWord, style: Theme.of(context).textTheme.labelSmall),
            for (final (i, pledge) in pledges.indexed)
              CheckboxListTile(
                value: _said[i],
                onChanged: (v) => setState(() => _said[i] = v ?? false),
                title: Text(pledge, style: const TextStyle(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.brand,
              ),
            const Divider(height: Gap.lg),
            SwitchListTile(
              value: _askEveryTime,
              onChanged: _setAsk,
              title: Text(
                s.askBeforeEveryTrade,
                style: const TextStyle(fontSize: 13.5),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.brand,
            ),
            Gap.h8,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(s.cancel),
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: FilledButton(
                    onPressed: _said.every((x) => x)
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: Text(s.placeTrade),
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

/// One of the app's rules: kept, in green; broken, in red with its cost.
class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.text,
    required this.broken,
    required this.penalty,
  });

  final String text;
  final bool broken;
  final String penalty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            broken ? Icons.cancel_rounded : Icons.check_circle_rounded,
            size: 18,
            color: broken ? AppColors.loss : AppColors.profit,
          ),
          Gap.w8,
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: broken ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (broken) ...[
            Gap.w8,
            Pill(text: penalty, color: AppColors.loss, dense: true),
          ],
        ],
      ),
    );
  }
}
