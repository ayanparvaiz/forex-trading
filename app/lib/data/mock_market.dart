import 'dart:async';
import 'dart:math' as math;

import '../models/candle.dart';
import '../models/instrument.dart';
import 'reference_rates.dart';

/// The practice market: real levels, simulated movement.
///
/// Each pair is anchored to the day's reference rate (the ECB's — see
/// [ReferenceRates]), so EUR/USD sits where EUR/USD actually is. The
/// movement around it is generated here, with the shape real forex has —
/// volatility that clusters, wicks longer than bodies — and a gentle pull
/// back toward the anchor so a long session does not wander off. Live
/// prices for an app's users need a paid licence; this is the honest free
/// alternative, and the trade screen says which it is.
class MockMarket {
  MockMarket({
    int seed = 20260922,
    Map<String, double>? anchors,
    this.anchorDate,
  }) : _random = math.Random(seed),
       _anchors = {..._fallbackAnchors, ...?anchors};

  final math.Random _random;

  /// Where each pair is anchored, starting from [_fallbackAnchors].
  final Map<String, double> _anchors;

  /// The date of the reference rates in use, or null for the built-in ones.
  String? anchorDate;

  /// Used until reference rates arrive: the ECB's of 25 September 2026.
  static const _fallbackAnchors = {
    'EUR/USD': 1.14030,
    'GBP/USD': 1.32524,
    'USD/JPY': 157.590,
  };

  /// Fraction of the distance to the anchor closed each tick. Half the gap
  /// goes in about forty minutes: enough to keep a session near the real
  /// level, too slow to flatten the moves traders practise on.
  static const _pullPerTick = 0.0003;

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

    var price = anchor(instrument);
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
      final upperWick =
          range * rng.nextDouble() * (rng.nextDouble() < 0.12 ? 0.9 : 0.3);
      final lowerWick =
          range * rng.nextDouble() * (rng.nextDouble() < 0.12 ? 0.9 : 0.3);

      candles.add(
        Candle(
          time: now.subtract(timeframe.duration * i),
          open: open,
          high: bodyHigh + upperWick,
          low: bodyLow - lowerWick,
          close: close,
        ),
      );

      price = close;
    }

    // However the walk wandered, it ends where the price is now: the live
    // price if other charts already set it, the anchor if this is the first.
    final end = _livePrices[instrument.symbol] ?? anchor(instrument);
    final shifted = _shift(candles, end - candles.last.close);
    _livePrices[instrument.symbol] = shifted.last.close;
    return shifted;
  }

  static List<Candle> _shift(List<Candle> candles, double by) => [
    for (final c in candles)
      Candle(
        time: c.time,
        open: c.open + by,
        high: c.high + by,
        low: c.low + by,
        close: c.close + by,
      ),
  ];

  /// Where [instrument] is anchored now.
  double anchor(Instrument instrument) =>
      _anchors[instrument.symbol] ?? _fallbackAnchors[instrument.symbol]!;

  /// Moves [instrument]'s anchor to [price].
  ///
  /// With [jump], the price and every chart move there at once, their shape
  /// kept — only fair with nothing open on the pair, since it would move
  /// every position's result in one step. Without, the price drifts there
  /// over the next hour, like a market that has somewhere to go.
  void setAnchor(Instrument instrument, double price, {bool jump = false}) {
    _anchors[instrument.symbol] = price;
    final live = _livePrices[instrument.symbol];
    if (!jump || live == null) return;
    final by = price - live;
    _livePrices[instrument.symbol] = price;
    for (final entry in _cache.entries) {
      if (!entry.key.startsWith(instrument.symbol)) continue;
      final moved = _shift(entry.value, by);
      entry.value
        ..clear()
        ..addAll(moved);
    }
  }

  /// Latest traded price (mid). The spread is applied at order time.
  double price(Instrument instrument) {
    if (!_livePrices.containsKey(instrument.symbol)) {
      candles(instrument);
    }
    return _livePrices[instrument.symbol]!;
  }

  /// What a buyer pays — mid plus half the spread.
  double ask(Instrument instrument) =>
      instrument.shiftByPips(price(instrument), instrument.spreadPips / 2);

  /// What a seller receives — mid minus half the spread.
  double bid(Instrument instrument) =>
      instrument.shiftByPips(price(instrument), -instrument.spreadPips / 2);

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
  double pressureOn(Instrument instrument) => _pressure[instrument.symbol] ?? 0;

  /// Nudges every price by a small random step, plus whatever the crowd is
  /// doing. Called on a timer so open positions show P&L moving the way they
  /// do on a real terminal.
  void tick() {
    for (final instrument in Instrument.all) {
      final current = price(instrument);

      final noise = instrument.pipSize * (_random.nextDouble() - 0.5) * 1.6;
      final crowd =
          instrument.pipSize * pressureOn(instrument) * _pressurePipsPerOrder;
      final pull = (anchor(instrument) - current) * _pullPerTick;
      final step = noise + crowd + pull;

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
