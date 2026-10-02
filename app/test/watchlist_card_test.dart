import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/account_scope.dart';
import 'package:forex_trading/data/account_store.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/data/trade_focus.dart';
import 'package:forex_trading/data/watchlist.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/candle.dart';
import 'package:forex_trading/models/instrument.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/watchlist_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test("a day of hourly candles is the last 24 closes", () {
    final t = DateTime(2026, 10, 2);
    final candles = [
      for (var i = 0; i < 30; i++)
        Candle(time: t, open: 1, high: 1, low: 1, close: i.toDouble()),
    ];
    expect(dayOfHours(candles), [for (var i = 6; i < 30; i++) i.toDouble()]);
    expect(dayOfHours(candles.take(5).toList()), [0, 1, 2, 3, 4]);
  });

  Future<(Watchlist, AccountStore)> pump(
    WidgetTester tester, {
    List<String> starred = const [],
    AppLanguage language = AppLanguage.en,
  }) async {
    SharedPreferences.setMockInitialValues({'watchlist': starred});
    final prefs = await SharedPreferences.getInstance();
    final list = Watchlist(prefs: prefs);
    final session = SessionController(LocalAuthRepository(prefs: prefs))
      ..setLanguage(language);
    final store = AccountStore();
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: AccountScope(
          store: store,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: SingleChildScrollView(child: WatchlistCard(list: list)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (list, store);
  }

  Future<void> stop(WidgetTester tester, AccountStore store) async {
    // The market ticks every second; stop it before the test ends.
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  }

  testWidgets('nothing starred says how to star', (tester) async {
    final (_, store) = await pump(tester);
    expect(find.textContaining('Tap ☆'), findsOneWidget);
    await stop(tester, store);
  });

  testWidgets('starred pairs, with their price; a tap asks for the trade tab', (
    tester,
  ) async {
    final (list, store) = await pump(tester, starred: ['USD/JPY']);
    expect(find.text('USD/JPY'), findsOneWidget);
    expect(find.text('EUR/USD'), findsNothing);
    expect(
      find.text(
        Instrument.usdjpy.formatPrice(store.market.price(Instrument.usdjpy)),
      ),
      findsOneWidget,
    );

    await list.toggle(Instrument.eurusd);
    await tester.pump();
    expect(find.text('EUR/USD'), findsOneWidget);

    Instrument? asked;
    void heard() => asked = tradeFocus.pair;
    tradeFocus.addListener(heard);
    await tester.tap(find.text('EUR/USD'));
    tradeFocus.removeListener(heard);
    expect(asked, Instrument.eurusd);
    await stop(tester, store);
  });

  testWidgets('fits a small phone, in Bangla', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final (_, store) = await pump(
      tester,
      starred: ['EUR/USD', 'GBP/USD', 'USD/JPY'],
      language: AppLanguage.bn,
    );
    expect(tester.takeException(), isNull);
    await stop(tester, store);
  });
}
