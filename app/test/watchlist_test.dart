import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/watchlist.dart';
import 'package:forex_trading/models/instrument.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starred pairs come first, and are remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final list = Watchlist(prefs: prefs);
    await list.load();
    expect(list.pairs, isEmpty);

    await list.toggle(Instrument.usdjpy);
    await list.toggle(Instrument.gbpusd);
    expect(list.pairs, [Instrument.usdjpy, Instrument.gbpusd]);
    expect(list.starredFirst(Instrument.all), [
      Instrument.gbpusd,
      Instrument.usdjpy,
      Instrument.eurusd,
    ]);

    await list.toggle(Instrument.usdjpy);
    expect(list.contains(Instrument.usdjpy), isFalse);

    final again = Watchlist(prefs: prefs);
    await again.load();
    expect(again.pairs, [Instrument.gbpusd]);
  });

  test('a pair the app no longer has is forgotten', () async {
    SharedPreferences.setMockInitialValues({
      'watchlist': ['XAU/USD', 'EUR/USD'],
    });
    final list = Watchlist(prefs: await SharedPreferences.getInstance());
    await list.load();
    expect(list.pairs, [Instrument.eurusd]);
  });
}
