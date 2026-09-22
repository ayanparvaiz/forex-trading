import 'dart:async';
import 'dart:math' as math;

import '../models/candle.dart';
import '../models/instrument.dart';

/// Stand-in for the live market feed.
///
/// Generates candles with the shape real forex has — volatility that clusters,
/// occasional gaps, wicks longer than bodies — so the chart and the maths can
/// be built and tested before a Twelve Data key exists. The public surface
/// matches what the real feed will expose, so swapping it is a one-line change.
class MockMarket {
  MockMarket({int seed = 20260922}) : _random = math.Random(seed);

  final math.Random _random;

  /// Anchor prices, roughly where these pairs have been trading.
  static const _basePrices = {
    'EUR/USD': 1.08500,
    'GBP/USD': 1.26500,
    'USD/JPY': 150.500,
  };

  /// Typical candle range in pips, per timeframe. Real ranges scale with the
  /// square root of time, not linearly.
  static const _baseRangePips = {
    Timeframe.m5: 4.0,
    Timeframe.m15: 7.0,
    Timeframe.h1: 15.0,
    Timeframe.h4: 32.0,
    Timeframe.d1: 75.0,
  };

  final Map<String, List<Candle>> _cache = {};
  final Map<String, double> _livePrices = {};

  /// Net order flow per pair: positive when the crowd is buying.
  final Map<String, double> _pressure = {};

  /// How far one net order moves the price, in pips per tick. Small on purpose
  /// — the crowd should tilt the market, not teleport it.
  static const _pressurePipsPerOrder = 0.18;

  /// Fraction of the pressure that survives each tick. Order flow should fade
  /// within a minute or so, otherwise one busy morning pins the price forever.
  static const _pressureDecay = 0.93;

  /// Historical candles ending at the most recent close.
  List<Candle> candles(
    Instrument instrument, {
    Timeframe timeframe = Timeframe.h1,
    int count = 120,
  }) {
    final key = '${instrument.symbol}_${timeframe.name}_$count';
    return _cache.putIfAbsent(
      key,
      () => _generate(instrument, timeframe, count),
    );
  }

  List<Candle> _generate(
    Instrument instrument,
    Timeframe timeframe,
    int count,
  ) {
    // A per-series seed keeps each pair and timeframe stable across rebuilds
    // while still looking different from one another.
    final rng = math.Random(
      instrument.symbol.hashCode ^ timeframe.index * 7919,
    );

    final pip = instrument.pipSize;
    final baseRange = _baseRangePips[timeframe]! * pip;

    var price = _basePrices[instrument.symbol]!;
    // Start the walk below the anchor so the visible window usually trends up
    // into the current price rather than falling off the right edge.
    price -= baseRange * count * 0.012;

    var volatility = 1.0;
    final now = DateTime.now();
    final candles = <Candle>[];

    for (var i = count - 1; i >= 0; i--) {
      // Volatility clusters: quiet periods follow quiet periods. This is what
      // makes a generated chart look real instead of like static.
      volatility += (rng.nextDouble() - 0.5) * 0.35;
      volatility = volatility.clamp(0.45, 2.1);

      final range = baseRange * volatility * (0.6 + rng.nextDouble() * 0.8);

      final open = price;
      // Drift is slightly positive so the series has structure to trade.
      final drift = (rng.nextDouble() - 0.47) * range * 0.9;
      final close = open + drift;

      final bodyHigh = math.max(open, close);
      final bodyLow = math.min(open, close);

      // Wicks: usually short, occasionally a long rejection tail.
      final upperWick = range * rng.nextDouble() * (rng.nextDouble() < 0.12 ? 0.9 : 0.3);
      final lowerWick = range * rng.nextDouble() * (rng.nextDouble() < 0.12 ? 0.9 : 0.3);

      candles.add(Candle(
        time: now.subtract(timeframe.duration * i),
        open: open,
        high: bodyHigh + upperWick,
        low: bodyLow - lowerWick,
        close: close,
      ));

      price = close;
    }

    _livePrices[instrument.symbol] = candles.last.close;
    return candles;
  }

  /// Latest traded price (mid). The spread is applied at order time.
  double price(Instrument instrument) {
    if (!_livePrices.containsKey(instrument.symbol)) {
      candles(instrument);
    }
    return _livePrices[instrument.symbol]!;
  }

  /// What a buyer pays — mid plus half the spread.
  double ask(Instrument instrument) => instrument.shiftByPips(
        price(instrument),
        instrument.spreadPips / 2,
      );

  /// What a seller receives — mid minus half the spread.
  double bid(Instrument instrument) => instrument.shiftByPips(
        price(instrument),
        -instrument.spreadPips / 2,
      );

  /// Records one order against a pair: `+1` for a buy, `-1` for a sell.
  ///
  /// This is what makes the market feel populated. Prices are not a private
  /// random walk per phone — when the crowd leans one way, the price leans with
  /// it, and everyone trading that pair feels the same move.
  void applyPressure(Instrument instrument, double direction) {
    _pressure[instrument.symbol] =
        (_pressure[instrument.symbol] ?? 0) + direction;
  }

  /// Net order flow currently pushing a pair. Positive means net buying.
  double pressureOn(Instrument instrument) =>
      _pressure[instrument.symbol] ?? 0;

  /// Nudges every price by a small random step, plus whatever the crowd is
  /// doing. Called on a timer so open positions show P&L moving the way they
  /// do on a real terminal.
  void tick() {
    for (final instrument in Instrument.all) {
      final current = price(instrument);

      final noise = instrument.pipSize * (_random.nextDouble() - 0.5) * 1.6;
      final crowd = instrument.pipSize *
          pressureOn(instrument) *
          _pressurePipsPerOrder;
      final step = noise + crowd;

      _pressure[instrument.symbol] = pressureOn(instrument) * _pressureDecay;
      _livePrices[instrument.symbol] = current + step;

      // Keep the last candle of every cached series in sync with the tick, so
      // the chart's right edge tracks the live price.
      for (final entry in _cache.entries) {
        if (!entry.key.startsWith(instrument.symbol)) continue;
        final series = entry.value;
        if (series.isEmpty) continue;
        final last = series.last;
        final next = _livePrices[instrument.symbol]!;
        series[series.length - 1] = Candle(
          time: last.time,
          open: last.open,
          high: math.max(last.high, next),
          low: math.min(last.low, next),
          close: next,
        );
      }
    }
  }

  /// Emits on every tick, roughly once a second.
  Stream<void> ticks() async* {
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 1));
      tick();
      yield null;
    }
  }
}
