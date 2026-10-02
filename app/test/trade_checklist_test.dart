import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/data/trade_checklist_pref.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/trade.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/trade_checklist_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late TradeChecklistPref pref;

  Future<List<bool>> open(
    WidgetTester tester,
    TradeChecks checks, {
    AppLanguage language = AppLanguage.en,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    pref = TradeChecklistPref(prefs: prefs);
    final session = SessionController(LocalAuthRepository(prefs: prefs))
      ..setLanguage(language);
    final answers = <bool>[];
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => answers.add(
                  await showTradeChecklist(context, checks, pref: pref),
                ),
                child: const Text('trade'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('trade'));
    await tester.pumpAndSettle();
    return answers;
  }

  const clean = TradeChecks(
    violations: {},
    riskPoints: '100',
    maxRiskPercent: 1,
    minRiskReward: 1.5,
    maxTradesPerDay: 3,
  );

  FilledButton place(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Place trade'),
  );

  testWidgets('the rules kept, then three things to say before it goes', (
    tester,
  ) async {
    final answers = await open(tester, clean);
    expect(find.text('Risk within your limit (1% at most)'), findsOneWidget);
    expect(find.text('Target at least 1.5× the risk'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsNothing);

    expect(place(tester).onPressed, isNull);
    await tester.tap(find.textContaining('losing 100 points'));
    await tester.tap(find.textContaining('my setup'));
    await tester.pump();
    expect(place(tester).onPressed, isNull, reason: 'two of three');
    await tester.tap(find.textContaining("I'm calm"));
    await tester.pump();
    expect(place(tester).onPressed, isNotNull);

    await tester.tap(find.text('Place trade'));
    await tester.pumpAndSettle();
    expect(answers, [true]);
  });

  testWidgets('a broken rule shows in red, with what it costs', (tester) async {
    await open(
      tester,
      const TradeChecks(
        violations: {RuleViolation.revengeTrade},
        riskPoints: '100',
        maxRiskPercent: 1,
        minRiskReward: 1.5,
        maxTradesPerDay: 3,
      ),
    );
    expect(find.text('Revenge trade'), findsOneWidget);
    expect(find.text('−25 points'), findsOneWidget);
    expect(find.text('Not straight after a loss'), findsNothing);
  });

  testWidgets('cancel is no; turning it off is remembered', (tester) async {
    final answers = await open(tester, clean);
    expect(await pref.isOn(), isTrue);
    await tester.tap(find.text('Show before every trade'));
    await tester.pump();
    expect(await pref.isOn(), isFalse);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });

  testWidgets('fits a small phone, in Bangla', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await open(
      tester,
      const TradeChecks(
        violations: {
          RuleViolation.riskTooHigh,
          RuleViolation.poorRiskReward,
          RuleViolation.revengeTrade,
          RuleViolation.overtrading,
        },
        riskPoints: '1,250',
        maxRiskPercent: 1,
        minRiskReward: 1.5,
        maxTradesPerDay: 3,
      ),
      language: AppLanguage.bn,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('ট্রেড নিন'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.takeException(), isNull);
  });
}
