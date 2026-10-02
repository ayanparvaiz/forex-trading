import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/price_alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('rings once, on the way up or the way down, and is gone', () async {
    SharedPreferences.setMockInitialValues({});
    final alerts = PriceAlerts(prefs: await SharedPreferences.getInstance());
    await alerts.load('u1');
    await alerts.add('EUR/USD', 1.1420, 1.1400); // up
    await alerts.add('USD/JPY', 150.00, 151.00); // down
    final rang = <String>[];
    alerts.rang.listen((a) => rang.add(a.symbol));

    final prices = {'EUR/USD': 1.1410, 'USD/JPY': 150.5};
    alerts.check((s) => prices[s]);
    await pumpEventQueue();
    expect(rang, isEmpty);

    prices['EUR/USD'] = 1.1421;
    alerts.check((s) => prices[s]);
    await pumpEventQueue();
    expect(rang, ['EUR/USD']);
    expect([for (final a in alerts.alerts) a.symbol], ['USD/JPY']);

    prices['USD/JPY'] = 149.9;
    alerts.check((s) => prices[s]);
    alerts.check((s) => prices[s]);
    await pumpEventQueue();
    expect(rang, ['EUR/USD', 'USD/JPY'], reason: 'each only once');
  });

  test("kept per account on this phone", () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = PriceAlerts(prefs: prefs);
    await a.load('u1');
    await a.add('GBP/USD', 1.33, 1.32);

    final b = PriceAlerts(prefs: prefs);
    await b.load('u1');
    expect(b.alerts.single.price, 1.33);
    await b.load('u2');
    expect(b.alerts, isEmpty);
  });

  test('no more than ten, and none at the price it already is', () async {
    SharedPreferences.setMockInitialValues({});
    final alerts = PriceAlerts(prefs: await SharedPreferences.getInstance());
    await alerts.load('u1');
    expect(await alerts.add('EUR/USD', 1.14, 1.14), isFalse);
    for (var i = 0; i < PriceAlerts.max; i++) {
      expect(await alerts.add('EUR/USD', 1.15 + i / 1000, 1.14), isTrue);
    }
    expect(await alerts.add('EUR/USD', 1.2, 1.14), isFalse);
  });
}
