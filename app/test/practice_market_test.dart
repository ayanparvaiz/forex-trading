import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/account_store.dart';
import 'package:forex_trading/data/mock_market.dart';
import 'package:forex_trading/data/reference_rates.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/candle.dart';
import 'package:forex_trading/models/instrument.dart';

/// The practice market sits at real levels — the day's reference rates —
/// and says it is practice.
void main() {
  const eur = Instrument.eurusd;
  const jpy = Instrument.usdjpy;

  group('reference rates', () {
    test('read from what the worker sends', () {
      final r = ReferenceRates.fromJson({
        'date': '2026-09-25',
        'pairs': {'EUR/USD': 1.1403, 'GBP/USD': 1.32524, 'USD/JPY': 157.59},
      })!;
      expect(r.pairs['EUR/USD'], 1.1403);
      expect(r.date, '2026-09-25');
    });

    test('an absurd or unknown pair is dropped; nothing usable is nothing', () {
      final r = ReferenceRates.fromJson({
        'date': '2026-09-25',
        'pairs': {'EUR/USD': 11.4, 'USD/JPY': 157.59, 'BTC/USD': 60000},
      })!;
      expect(r.pairs.keys, ['USD/JPY']);
      expect(ReferenceRates.fromJson({'date': 'x', 'pairs': {}}), isNull);
      expect(ReferenceRates.fromJson('nonsense'), isNull);
    });
  });

  group('the market', () {
    test('starts at the anchor, on every timeframe alike', () {
      final m = MockMarket(anchors: {'EUR/USD': 1.14030});
      expect(m.price(eur), closeTo(1.14030, 1e-9));
      for (final tf in Timeframe.values) {
        expect(
          m.candles(eur, timeframe: tf).last.close,
          closeTo(1.14030, 1e-9),
        );
      }
    });

    test('without rates it starts from the built-in ones, which are real', () {
      expect(MockMarket().price(jpy), closeTo(157.59, 1e-9));
    });

    test('a jump moves the price and the chart, keeping its shape', () {
      final m = MockMarket(anchors: {'EUR/USD': 1.10});
      final before = List<Candle>.of(m.candles(eur));
      m.setAnchor(eur, 1.15, jump: true);
      final after = m.candles(eur);
      expect(m.price(eur), closeTo(1.15, 1e-9));
      for (var i = 1; i < before.length; i++) {
        expect(
          after[i].close - after[i - 1].close,
          closeTo(before[i].close - before[i - 1].close, 1e-9),
        );
      }
    });

    test('otherwise it drifts there, not jumps', () {
      final m = MockMarket(anchors: {'EUR/USD': 1.10});
      m.price(eur);
      m.setAnchor(eur, 1.14);
      m.tick();
      expect(m.price(eur), lessThan(1.101), reason: 'no leap on the next tick');
      for (var i = 0; i < 20000; i++) {
        m.tick();
      }
      expect(m.price(eur), closeTo(1.14, 0.006));
    });
  });

  test('applying the day\'s rates, with nothing open, moves there at once', () {
    final store = AccountStore(market: MockMarket(anchors: {'EUR/USD': 1.08}));
    addTearDown(store.dispose);
    store.market.price(eur);
    store.applyReferenceRates(
      const ReferenceRates(pairs: {'EUR/USD': 1.1403}, date: '2026-09-25'),
    );
    expect(store.market.price(eur), closeTo(1.1403, 1e-9));
    expect(store.market.anchorDate, '2026-09-25');
  });

  test('the chart says these are practice prices, and from when', () {
    final en = Strings(AppLanguage.en);
    expect(
      en.practicePrices('2026-09-25'),
      'Practice prices — from ECB rates of 25 Sep, not live',
    );
    expect(
      en.practicePrices(null),
      'Practice prices — near real rates, not live',
    );
  });
}
