import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/habit_calendar.dart';
import '../data/session_controller.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// The last few months as squares, a column a week: green where every rule
/// was kept, amber where some were, red where none were, blank where nothing
/// was traded. As many weeks as fit.
class HabitCalendarCard extends StatelessWidget {
  const HabitCalendarCard({
    super.key,
    required this.trades,
    this.now = DateTime.now,
  });

  final List<Trade> trades;
  final DateTime Function() now;

  static const _cell = 13.0;
  static const _gap = 3.0;

  static Color colorOf(DayMark? mark) => switch (mark) {
    DayMark.clean => AppColors.profit,
    DayMark.mixed => AppColors.warning,
    DayMark.broken => AppColors.loss,
    null => AppColors.elevated,
  };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final today = now();
    final marks = dayMarks(trades);
    final streak = cleanStreak(marks, today);
    final todayDay = DateTime(today.year, today.month, today.day);

    return SectionCard(
      title: s.habitCalendar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final weeks = math.max(
                4,
                math.min(26, ((box.maxWidth + _gap) / (_cell + _gap)).floor()),
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, monday) in weekStarts(today, weeks).indexed)
                    Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : _gap),
                      child: Column(
                        children: [
                          for (var d = 0; d < 7; d++)
                            _Day(
                              day: DateTime(
                                monday.year,
                                monday.month,
                                monday.day + d,
                              ),
                              today: todayDay,
                              color: colorOf(
                                marks[DateTime(
                                  monday.year,
                                  monday.month,
                                  monday.day + d,
                                )],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          Gap.h12,
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.xs,
            children: [
              for (final (mark, label) in [
                (DayMark.clean, s.dayClean),
                (DayMark.mixed, s.dayMixed),
                (DayMark.broken, s.dayBroken),
                (null, s.dayNone),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorOf(mark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (streak > 0) ...[
            Gap.h8,
            Text(
              '🔥 ${s.cleanStreakDays(streak)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.profit,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.day, required this.today, required this.color});

  final DateTime day;
  final DateTime today;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final future = day.isAfter(today);
    return Container(
      width: HabitCalendarCard._cell,
      height: HabitCalendarCard._cell,
      margin: const EdgeInsets.only(bottom: HabitCalendarCard._gap),
      decoration: BoxDecoration(
        // Days still to come are left out, not shown as empty.
        color: future ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(3),
        border: day == today
            ? Border.all(color: AppColors.textSecondary, width: 1.2)
            : null,
      ),
    );
  }
}
