import 'package:flutter/material.dart';

import '../core/monthly_report.dart';
import '../data/account_scope.dart';
import '../data/chat_inbox.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/forward_sheet.dart';

/// Opens this month's report.
Future<void> openMonthlyReport(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const MonthlyReportScreen()));

/// A month of trading as a report card, a month at a time, back as far as
/// there are trades: the discipline score first, then the numbers, then the
/// one rule to fix — and a way to share it.
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _step(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final store = AccountScope.of(context);
    final report = MonthlyReport.of(store.trades, _month);
    final now = DateTime.now();
    final isThisMonth = _month.year == now.year && _month.month == now.month;
    final monthLabel = s.monthYear(_month);

    final fix = report.worstRule == null
        ? s.cleanMonth
        : '${s.fixNextMonth}: ${s.brokenTimes(report.worstRule!.label(s.isBangla), report.worstRuleCount)}';

    return Scaffold(
      appBar: AppBar(title: Text(s.monthlyReport)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _step(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: isThisMonth ? null : () => _step(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Gap.h12,
          if (report.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xxl),
              child: Text(
                s.noTradesInMonth(monthLabel),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            )
          else ...[
            SectionCard(
              child: Column(
                children: [
                  ScoreRing(
                    score: report.discipline,
                    grade: s.gradeFor(report.discipline),
                  ),
                  Gap.h8,
                  Text(
                    s.discipline,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Gap.h16,
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: s.tradeCount(report.trades),
                          value: '${(report.winRate * 100).round()}%',
                          hint: s.winRate,
                          align: CrossAxisAlignment.center,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: s.totalR,
                          value: rMultiple(report.totalR),
                          valueColor: report.totalR >= 0
                              ? AppColors.profit
                              : AppColors.loss,
                          align: CrossAxisAlignment.center,
                        ),
                      ),
                    ],
                  ),
                  Gap.h16,
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: s.journaledLabel,
                          value: '${report.journaled}/${report.trades}',
                          align: CrossAxisAlignment.center,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: s.daysTradedLabel,
                          value: '${report.daysTraded}',
                          align: CrossAxisAlignment.center,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: s.bestTradeLabel,
                          value: rMultiple(report.bestR ?? 0),
                          align: CrossAxisAlignment.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Gap.h12,
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color:
                    (report.worstRule == null
                            ? AppColors.profit
                            : AppColors.warning)
                        .withValues(alpha: 0.1),
                borderRadius: Radii.tile,
              ),
              child: Text(
                fix,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: report.worstRule == null
                      ? AppColors.profit
                      : AppColors.warning,
                ),
              ),
            ),
            if (InboxScope.of(context) != null) ...[
              Gap.h16,
              FilledButton.icon(
                onPressed: () => shareIntoChats(
                  context,
                  text: s.reportSummary(
                    monthLabel,
                    report.trades,
                    '${(report.winRate * 100).round()}%',
                    rMultiple(report.totalR),
                    report.discipline.toStringAsFixed(0),
                    fix,
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(s.shareInChat),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
