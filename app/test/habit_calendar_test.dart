import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/core/habit_calendar.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/trade.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/habit_calendar_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Trade closedOn(DateTime day, {bool broke = false}) => Trade(
    id: '${day.toIso8601String()}$broke',
    symbol: 'EUR/USD',
    direction: TradeDirection.buy,
    lots: 0.1,
    entryPrice: 1.14,
    stopPrice: 1.138,
    targetPrice: 1.144,
    openedAt: day,
    closedAt: day.add(const Duration(hours: 2)),
    exitPrice: 1.141,
    exitReason: ExitReason.manual,
    balanceAtEntry: 10000,
    reason: 'a reason long enough',
    violations: broke ? {RuleViolation.revengeTrade} : const {},
  );

  final oct1 = DateTime(2026, 10, 1, 9);
  final oct2 = DateTime(2026, 10, 2, 9);
  final sep30 = DateTime(2026, 9, 30, 9);

  test('a day is clean, mixed or broken by its closed trades', () {
    final marks = dayMarks([
      closedOn(sep30, broke: true),
      closedOn(oct1),
      closedOn(oct1, broke: true),
      closedOn(oct2),
      closedOn(oct2),
    ]);
    expect(marks[DateTime(2026, 9, 30)], DayMark.broken);
    expect(marks[DateTime(2026, 10, 1)], DayMark.mixed);
    expect(marks[DateTime(2026, 10, 2)], DayMark.clean);
    expect(marks.length, 3);
  });

  test('columns: Mondays, oldest first, ending this week', () {
    final weeks = weekStarts(DateTime(2026, 10, 2, 18), 3);
    expect(weeks, [
      DateTime(2026, 9, 14),
      DateTime(2026, 9, 21),
      DateTime(2026, 9, 28),
    ]);
  });

  test('a clean run: days without trades neither break nor add', () {
    final marks = dayMarks([
      closedOn(DateTime(2026, 9, 25, 9), broke: true),
      closedOn(DateTime(2026, 9, 28, 9)),
      closedOn(DateTime(2026, 9, 29, 9)),
      // 30 September: no trades.
      closedOn(oct1),
    ]);
    // A morning with no trade yet: yesterday's run still stands.
    expect(cleanStreak(marks, DateTime(2026, 10, 2, 8)), 3);
    expect(cleanStreak(marks, DateTime(2026, 9, 26, 8)), 0);
    expect(cleanStreak(const {}, oct2), 0);
  });

  for (final language in AppLanguage.values) {
    testWidgets('the calendar fits a small phone, in ${language.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final session = SessionController(
        LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
      )..setLanguage(language);
      await tester.pumpWidget(
        SessionScope(
          controller: session,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: HabitCalendarCard(
                  trades: [closedOn(oct1), closedOn(oct2)],
                  now: () => DateTime(2026, 10, 2, 18),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('🔥'), findsOneWidget);
    });
  }
}
