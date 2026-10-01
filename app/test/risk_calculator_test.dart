import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/screens/risk_calculator_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the size follows from the risk and the stop', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    )..setLanguage(AppLanguage.en);
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const RiskCalculatorScreen(balance: 10000),
        ),
      ),
    );

    // 1% of 10,000 is 100; 20 pips on EUR/USD is 200 a lot: half a lot.
    expect(find.text('0.50 lots'), findsOneWidget);

    // A stop twice as far: half the size, the same money at risk.
    await tester.enterText(find.widgetWithText(TextField, '20'), '40');
    await tester.pump();
    expect(find.text('0.25 lots'), findsOneWidget);
    expect(find.text('−100'), findsOneWidget);
    expect(find.text('+200'), findsOneWidget, reason: 'at 2 : 1');
  });
}
