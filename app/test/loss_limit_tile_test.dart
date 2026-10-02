import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/account_scope.dart';
import 'package:forex_trading/data/account_store.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/loss_limit.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/instrument.dart';
import 'package:forex_trading/models/trade.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/trade_screen.dart';
import 'package:forex_trading/screens/settings_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('picking a limit; turning it off waits for tomorrow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final limit = LossLimit(
      prefs: prefs,
      clock: () => DateTime(2026, 10, 2, 15),
    );
    final session = SessionController(LocalAuthRepository(prefs: prefs))
      ..setLanguage(AppLanguage.en);
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: LossLimitTile(limit: limit)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);

    await tester.tap(find.text('Daily loss limit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2% a day'));
    await tester.pumpAndSettle();
    expect(find.text('2% a day'), findsOneWidget);

    await tester.tap(find.text('Daily loss limit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(find.text('2% a day · Off from tomorrow'), findsOneWidget);
  });

  testWidgets('past the limit, the trade button stays shut until midnight', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = LocalAuthRepository(prefs: prefs);
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
    // A big position closed straight away: the spread alone loses ~2.4%.
    final market = store.market;
    final t = store.openTrade(
      instrument: Instrument.eurusd,
      direction: TradeDirection.buy,
      lots: 30,
      stopPrice: market.price(Instrument.eurusd) - 0.002,
      targetPrice: market.price(Instrument.eurusd) + 0.004,
      reason: 'a test of the daily loss limit',
    );
    store.closeTrade(t.id);
    await lossLimit.set(2);

    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: AccountScope(
          store: store,
          child: MaterialApp(theme: buildAppTheme(), home: const TradeScreen()),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining("Today's loss limit (2%)"), findsOneWidget);

    // The market ticks every second; stop it before the test ends.
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
