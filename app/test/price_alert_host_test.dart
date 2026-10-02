import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/account_scope.dart';
import 'package:forex_trading/data/account_store.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/price_alerts.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/instrument.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/price_alert_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('an alert rings over the app on the tick that reaches it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthRepository(
      prefs: await SharedPreferences.getInstance(),
    );
    await auth.signUp(
      username: 'tester',
      password: 'secret123',
      displayName: 'Tester',
      gender: Gender.male,
      language: AppLanguage.en,
      avatarId: 1,
    );
    final session = SessionController(auth);
    await session.restore();
    final store = AccountStore();

    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: AccountScope(
          store: store,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const PriceAlertHost(child: Scaffold(body: Text('app'))),
          ),
        ),
      ),
    );
    await tester.pump();

    // Set from "above" 2.0 — so any EUR/USD price at or below it rings.
    await priceAlerts.add('EUR/USD', 2.0, 2.5);
    expect(priceAlerts.alerts, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('EUR/USD reached'), findsOneWidget);
    expect(priceAlerts.alerts, isEmpty);
    expect(Instrument.eurusd.formatPrice(2.0), '2.00000');

    // Gone by itself.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('EUR/USD reached'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
