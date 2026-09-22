/// One OHLC bar.
///
/// Field order and types match the Twelve Data `/time_series` response so the
/// mock feed can be swapped for the live one without touching the chart.
class Candle {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;

  bool get isBullish => close >= open;

  /// Height of the filled body, ignoring wicks.
  double get bodyHigh => close > open ? close : open;
  double get bodyLow => close > open ? open : close;

  /// Full high-to-low range.
  double get range => high - low;

  factory Candle.fromTwelveData(Map<String, dynamic> json) => Candle(
        time: DateTime.parse(json['datetime'] as String),
        open: double.parse(json['open'] as String),
        high: double.parse(json['high'] as String),
        low: double.parse(json['low'] as String),
        close: double.parse(json['close'] as String),
      );

  Map<String, dynamic> toJson() => {
        'datetime': time.toIso8601String(),
        'open': open.toString(),
        'high': high.toString(),
        'low': low.toString(),
        'close': close.toString(),
      };
}

/// Chart timeframes, matching Twelve Data's `interval` parameter.
enum Timeframe {
  m5('5min', 'M5', Duration(minutes: 5)),
  m15('15min', 'M15', Duration(minutes: 15)),
  h1('1h', 'H1', Duration(hours: 1)),
  h4('4h', 'H4', Duration(hours: 4)),
  d1('1day', 'D1', Duration(days: 1));

  const Timeframe(this.apiValue, this.label, this.duration);

  /// Value the market-data API expects.
  final String apiValue;

  /// Short label shown on the chart toolbar.
  final String label;

  final Duration duration;
}
