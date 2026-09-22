import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/candle.dart';
import '../models/instrument.dart';
import '../theme/app_theme.dart';

/// A candlestick chart drawn straight onto a canvas.
///
/// Written by hand rather than pulled from a charting package: the app needs
/// exactly one chart, and it needs the stop and target lines drawn to the same
/// scale as the candles so the trader can *see* how far away their risk sits.
/// A dependency would cost more than it saved.
class CandleChart extends StatelessWidget {
  const CandleChart({
    super.key,
    required this.candles,
    required this.instrument,
    this.entryPrice,
    this.stopPrice,
    this.targetPrice,
    this.livePrice,
    this.height = 280,
    required this.entryLabel,
    required this.stopLabel,
    required this.targetLabel,
    required this.loadingLabel,
  });

  final List<Candle> candles;
  final Instrument instrument;

  /// Levels to overlay. Null hides the line.
  final double? entryPrice;
  final double? stopPrice;
  final double? targetPrice;
  final double? livePrice;

  final double height;

  /// Level names, passed in rather than looked up, so the painter stays free of
  /// any dependency on the widget tree.
  final String entryLabel;
  final String stopLabel;
  final String targetLabel;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            loadingLabel,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CandlePainter(
          candles: candles,
          instrument: instrument,
          entryPrice: entryPrice,
          stopPrice: stopPrice,
          targetPrice: targetPrice,
          livePrice: livePrice,
          entryLabel: entryLabel,
          stopLabel: stopLabel,
          targetLabel: targetLabel,
        ),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter({
    required this.candles,
    required this.instrument,
    this.entryPrice,
    this.stopPrice,
    this.targetPrice,
    this.livePrice,
    required this.entryLabel,
    required this.stopLabel,
    required this.targetLabel,
  });

  final List<Candle> candles;
  final Instrument instrument;
  final double? entryPrice;
  final double? stopPrice;
  final double? targetPrice;
  final double? livePrice;
  final String entryLabel;
  final String stopLabel;
  final String targetLabel;

  /// Width reserved on the right for price labels.
  static const _axisWidth = 62.0;
  static const _topPad = 10.0;
  static const _bottomPad = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - _axisWidth;
    if (plotWidth <= 0) return;

    // Scale to the candles *and* any overlaid level, so a stop below the
    // visible range still shows up instead of being silently clipped.
    var low = candles.first.low;
    var high = candles.first.high;
    for (final c in candles) {
      low = math.min(low, c.low);
      high = math.max(high, c.high);
    }
    for (final level in [entryPrice, stopPrice, targetPrice, livePrice]) {
      if (level == null) continue;
      low = math.min(low, level);
      high = math.max(high, level);
    }

    // Breathing room, and a guard against a flat series collapsing the scale.
    final span = math.max(high - low, instrument.pipSize);
    low -= span * 0.06;
    high += span * 0.06;

    final plotHeight = size.height - _topPad - _bottomPad;
    double y(double price) =>
        _topPad + (high - price) / (high - low) * plotHeight;

    _paintGrid(canvas, size, plotWidth, low, high, y);
    _paintCandles(canvas, plotWidth, y);

    // Levels last, so they sit on top of the candles.
    if (targetPrice != null) {
      _paintLevel(canvas, size, plotWidth, y(targetPrice!), targetPrice!,
          AppColors.profit, targetLabel);
    }
    if (stopPrice != null) {
      _paintLevel(canvas, size, plotWidth, y(stopPrice!), stopPrice!,
          AppColors.loss, stopLabel);
    }
    if (entryPrice != null) {
      _paintLevel(canvas, size, plotWidth, y(entryPrice!), entryPrice!,
          AppColors.textSecondary, entryLabel);
    }
    if (livePrice != null) {
      _paintLevel(canvas, size, plotWidth, y(livePrice!), livePrice!,
          AppColors.brand, null);
    }
  }

  void _paintGrid(
    Canvas canvas,
    Size size,
    double plotWidth,
    double low,
    double high,
    double Function(double) y,
  ) {
    final line = Paint()
      ..color = AppColors.border.withValues(alpha: 0.45)
      ..strokeWidth = 1;

    const divisions = 4;
    for (var i = 0; i <= divisions; i++) {
      final price = low + (high - low) * i / divisions;
      final dy = y(price);
      canvas.drawLine(Offset(0, dy), Offset(plotWidth, dy), line);
      _paintAxisLabel(canvas, size, dy, instrument.formatPrice(price));
    }
  }

  void _paintAxisLabel(Canvas canvas, Size size, double dy, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontFeatures: tabularFigures,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(size.width - tp.width - 6, dy - tp.height / 2),
    );
  }

  void _paintCandles(Canvas canvas, double plotWidth, double Function(double) y) {
    final slot = plotWidth / candles.length;
    // Leave a gap between candles, but never let a body vanish entirely.
    final bodyWidth = math.max(slot * 0.62, 1.0);

    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final cx = slot * i + slot / 2;
      final color = c.isBullish ? AppColors.profit : AppColors.loss;

      canvas.drawLine(
        Offset(cx, y(c.high)),
        Offset(cx, y(c.low)),
        Paint()
          ..color = color
          ..strokeWidth = math.max(slot * 0.12, 1.0),
      );

      final top = y(c.bodyHigh);
      final bottom = y(c.bodyLow);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cx - bodyWidth / 2,
            top,
            cx + bodyWidth / 2,
            // A doji would be zero-height and invisible; give it a hairline.
            math.max(bottom, top + 1),
          ),
          const Radius.circular(1),
        ),
        Paint()..color = color,
      );
    }
  }

  void _paintLevel(
    Canvas canvas,
    Size size,
    double plotWidth,
    double dy,
    double price,
    Color color,
    String? label,
  ) {
    if (dy.isNaN || dy.isInfinite) return;

    _paintDashedLine(canvas, dy, plotWidth, color);

    // Price tag on the axis.
    final tp = TextPainter(
      text: TextSpan(
        text: instrument.formatPrice(price),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFeatures: tabularFigures,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tagRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width - tp.width - 12,
        dy - tp.height / 2 - 3,
        tp.width + 10,
        tp.height + 6,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(tagRect, Paint()..color = color);
    tp.paint(canvas, Offset(size.width - tp.width - 7, dy - tp.height / 2));

    if (label == null) return;

    // Name of the level, pinned to the left edge.
    final lp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, dy - lp.height / 2 - 2, lp.width + 8, lp.height + 4),
      const Radius.circular(3),
    );
    canvas.drawRRect(bg, Paint()..color = AppColors.bg.withValues(alpha: 0.85));
    lp.paint(canvas, Offset(6, dy - lp.height / 2));
  }

  void _paintDashedLine(Canvas canvas, double dy, double plotWidth, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;

    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < plotWidth) {
      canvas.drawLine(
        Offset(x, dy),
        Offset(math.min(x + dash, plotWidth), dy),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.candles != candles ||
      old.entryPrice != entryPrice ||
      old.stopPrice != stopPrice ||
      old.targetPrice != targetPrice ||
      old.livePrice != livePrice;
}
