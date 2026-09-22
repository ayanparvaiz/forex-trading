/// A tradable forex pair, with the numbers needed to price it correctly.
///
/// Everything a position-size or P&L calculation needs lives here, so the maths
/// never hard-codes "one pip is 0.0001" — that is false for JPY pairs.
class Instrument {
  const Instrument({
    required this.symbol,
    required this.name,
    required this.pipSize,
    required this.decimals,
    required this.spreadPips,
    required this.pipValuePerLot,
    required this.swapLongPerLot,
    required this.swapShortPerLot,
  });

  /// Ticker as traders write it, e.g. `EUR/USD`.
  final String symbol;

  /// Human label shown under the ticker.
  final String name;

  /// Price movement of one pip. 0.0001 for most pairs, 0.01 for JPY pairs.
  final double pipSize;

  /// Decimal places to render. One more than the pip decimal, for the pipette.
  final int decimals;

  /// Typical retail spread, charged on entry. This is the cost most demo
  /// accounts hide — and the reason demo profits vanish on a live account.
  final double spreadPips;

  /// USD value of one pip on one standard lot (100,000 units).
  ///
  /// Exactly 10.00 for pairs quoted in USD. JPY pairs vary with the rate; we
  /// use a representative constant, which is honest enough for a simulator and
  /// far better than pretending the pair behaves like EUR/USD.
  final double pipValuePerLot;

  /// Overnight financing per standard lot, charged when a position is held
  /// past the daily rollover. Negative means it costs the trader money.
  final double swapLongPerLot;
  final double swapShortPerLot;

  /// Smallest tradable size at a typical retail broker: one micro lot.
  static const double minLot = 0.01;

  /// Units of base currency in one standard lot.
  static const double contractSize = 100000;

  /// Price formatted the way a terminal shows it, e.g. `1.08453`.
  String formatPrice(double price) => price.toStringAsFixed(decimals);

  /// Distance between two prices, expressed in pips.
  double pipsBetween(double a, double b) => (a - b).abs() / pipSize;

  /// Move a price by a number of pips.
  double shiftByPips(double price, double pips) => price + pips * pipSize;

  static const eurusd = Instrument(
    symbol: 'EUR/USD',
    name: 'ইউরো / ইউএস ডলার',
    pipSize: 0.0001,
    decimals: 5,
    spreadPips: 0.8,
    pipValuePerLot: 10,
    swapLongPerLot: -7.2,
    swapShortPerLot: 2.1,
  );

  static const gbpusd = Instrument(
    symbol: 'GBP/USD',
    name: 'ব্রিটিশ পাউন্ড / ইউএস ডলার',
    pipSize: 0.0001,
    decimals: 5,
    spreadPips: 1.3,
    pipValuePerLot: 10,
    swapLongPerLot: -6.4,
    swapShortPerLot: 1.2,
  );

  static const usdjpy = Instrument(
    symbol: 'USD/JPY',
    name: 'ইউএস ডলার / জাপানি ইয়েন',
    pipSize: 0.01,
    decimals: 3,
    spreadPips: 1.0,
    pipValuePerLot: 6.7,
    swapLongPerLot: 4.8,
    swapShortPerLot: -11.3,
  );

  static const all = [eurusd, gbpusd, usdjpy];

  static Instrument bySymbol(String symbol) =>
      all.firstWhere((i) => i.symbol == symbol, orElse: () => eurusd);
}
