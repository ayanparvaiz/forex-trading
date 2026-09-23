import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Renders a mark to PNG bytes.
///
/// The launcher-icon and native-splash tooling both want image files, so the
/// PNGs in `assets/` are generated from this same painter rather than drawn by
/// hand somewhere else. One source, no chance of the icon and the in-app logo
/// drifting apart.
///
/// [inset] shrinks the mark inside the canvas, which Android adaptive icons
/// need — their outer third can be cropped by the launcher's mask.
Future<Uint8List> renderLogoPng({
  required LogoMark mark,
  required int pixels,
  bool background = true,
  double inset = 1.0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = pixels.toDouble();

  if (inset != 1.0) {
    final offset = size * (1 - inset) / 2;
    canvas.translate(offset, offset);
    canvas.scale(inset);
  }

  _LogoPainter(
    mark: mark,
    background: background,
  ).paint(canvas, Size(size, size));

  final image = await recorder.endRecording().toImage(pixels, pixels);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// The candidate marks.
///
/// This app is two things at once — a market and a place people talk in — and
/// a logo that only shows candlesticks describes half of it. Every mark here
/// fuses the two rather than picking one.
///
/// All are drawn rather than loaded, so one file covers the 24px nav icon and
/// the 1024px store listing with no export step and no blurry midpoint.
enum LogoMark {
  /// A speech bubble with a market inside it. The most direct reading of
  /// "people talking about charts".
  bubble,

  /// A candle body carrying a speech-bubble tail, so the instrument and the
  /// message are literally the same shape.
  fusion,

  /// Connected nodes climbing like a chart, the middle one a candle. A social
  /// graph that happens to trend.
  network,

  /// People gathered in a ring around a candle — the community around the
  /// market, which is the actual product.
  circle,
}

/// The app mark.
///
/// [size] is the full box. Every proportion inside is a fraction of it, so the
/// logo is identical at 24 and at 1024.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.mark = LogoMark.bubble,
    this.size = 96,
    this.background = true,
    this.progress = 1.0,
  });

  final LogoMark mark;
  final double size;

  /// Draws the rounded tile behind the mark. Off when the logo sits on a
  /// surface that already provides one.
  final bool background;

  /// 0 to 1. Below 1 the candles inside the mark are still rising, which is
  /// what the splash animates. Everywhere else this stays at 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(
          mark: mark,
          background: background,
          progress: progress,
        ),
      ),
    );
  }
}

/// Mark plus wordmark, for splash screens and the login header.
class AppLogoLockup extends StatelessWidget {
  const AppLogoLockup({
    super.key,
    this.mark = LogoMark.bubble,
    this.size = 64,
    this.title = 'Forex Trading',
    this.subtitle,
  });

  final LogoMark mark;
  final double size;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(mark: mark, size: size),
        SizedBox(width: size * 0.22),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.1,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: size * 0.2,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({
    required this.mark,
    required this.background,
    this.progress = 1.0,
  });

  final LogoMark mark;
  final bool background;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);

    if (background) _paintTile(canvas, s);

    switch (mark) {
      case LogoMark.bubble:
        _paintBubble(canvas, s);
      case LogoMark.fusion:
        _paintFusion(canvas, s);
      case LogoMark.network:
        _paintNetwork(canvas, s);
      case LogoMark.circle:
        _paintCircle(canvas, s);
    }
  }

  /// The rounded tile. A 24% radius, close to what iOS masks app icons to, so
  /// the mark is never clipped on device.
  void _paintTile(Canvas canvas, double s) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s),
        Radius.circular(s * 0.24),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16232B), Color(0xFF0B141A)],
        ).createShader(Rect.fromLTWH(0, 0, s, s)),
    );
  }

  /// A plain candle: wick behind, rounded body on top.
  void _candle(
    Canvas canvas, {
    required double cx,
    required double width,
    required double bodyTop,
    required double bodyBottom,
    required double wickTop,
    required double wickBottom,
    required Color color,
  }) {
    canvas.drawLine(
      Offset(cx, wickTop),
      Offset(cx, wickBottom),
      Paint()
        ..color = color
        ..strokeWidth = width * 0.3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - width / 2, bodyTop, cx + width / 2, bodyBottom),
        Radius.circular(width * 0.28),
      ),
      Paint()..color = color,
    );
  }

  // --- Bubble --------------------------------------------------------------

  void _paintBubble(Canvas canvas, double s) {
    final rect = Rect.fromLTRB(s * 0.14, s * 0.18, s * 0.86, s * 0.68);
    final body = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.16));

    // Tail on the lower left, the way a sent message points back at its sender.
    final tail = Path()
      ..moveTo(s * 0.3, s * 0.64)
      ..lineTo(s * 0.26, s * 0.86)
      ..lineTo(s * 0.5, s * 0.66)
      ..close();

    final fill = Paint()..color = AppColors.brand;
    canvas.drawRRect(body, fill);
    canvas.drawPath(tail, fill);

    // The market, sitting inside the message.
    final w = s * 0.1;
    final gap = s * 0.055;
    final cx = s * 0.5;
    const dark = Color(0xFF06231C);

    /// Each candle grows upward from its own base, staggered, so the mark
    /// assembles the way a chart prints rather than just fading in.
    void grown({
      required double x,
      required double top,
      required double bottom,
      required double wickTop,
      required double wickBottom,
      required double delay,
    }) {
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) return;

      // Ease out, so the candles settle instead of snapping.
      final eased = 1 - math.pow(1 - t, 3).toDouble();
      _candle(
        canvas,
        cx: x,
        width: w,
        bodyTop: bottom - (bottom - top) * eased,
        bodyBottom: bottom,
        wickTop: bottom - (bottom - wickTop) * eased,
        wickBottom: wickBottom,
        color: dark,
      );
    }

    grown(
      x: cx - w - gap,
      top: s * 0.4,
      bottom: s * 0.55,
      wickTop: s * 0.35,
      wickBottom: s * 0.59,
      delay: 0.0,
    );
    grown(
      x: cx,
      top: s * 0.29,
      bottom: s * 0.52,
      wickTop: s * 0.25,
      wickBottom: s * 0.57,
      delay: 0.18,
    );
    grown(
      x: cx + w + gap,
      top: s * 0.34,
      bottom: s * 0.46,
      wickTop: s * 0.29,
      wickBottom: s * 0.51,
      delay: 0.36,
    );
  }

  // --- Fusion --------------------------------------------------------------

  /// Two candles whose bodies carry speech-bubble tails.
  ///
  /// The whole idea of the app in one shape: a trade is a message. Red and
  /// green because both get talked about.
  void _paintFusion(Canvas canvas, double s) {
    void bubbleCandle({
      required double cx,
      required double width,
      required double top,
      required double bottom,
      required double wickTop,
      required double wickBottom,
      required Color color,
      required bool tailLeft,
    }) {
      canvas.drawLine(
        Offset(cx, wickTop),
        Offset(cx, wickBottom),
        Paint()
          ..color = color
          ..strokeWidth = width * 0.26
          ..strokeCap = StrokeCap.round,
      );

      final paint = Paint()..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - width / 2, top, cx + width / 2, bottom),
          Radius.circular(width * 0.34),
        ),
        paint,
      );

      // The tail is what turns a candle body into a message.
      final x = tailLeft ? cx - width / 2 : cx + width / 2;
      final dir = tailLeft ? -1 : 1;
      canvas.drawPath(
        Path()
          ..moveTo(x, bottom - width * 0.5)
          ..lineTo(x + dir * width * 0.42, bottom + width * 0.34)
          ..lineTo(x, bottom - width * 0.05)
          ..close(),
        paint,
      );
    }

    bubbleCandle(
      cx: s * 0.36,
      width: s * 0.2,
      top: s * 0.26,
      bottom: s * 0.56,
      wickTop: s * 0.19,
      wickBottom: s * 0.63,
      color: AppColors.profit,
      tailLeft: true,
    );
    bubbleCandle(
      cx: s * 0.66,
      width: s * 0.16,
      top: s * 0.44,
      bottom: s * 0.68,
      wickTop: s * 0.38,
      wickBottom: s * 0.75,
      color: AppColors.loss,
      tailLeft: false,
    );
  }

  // --- Network -------------------------------------------------------------

  void _paintNetwork(Canvas canvas, double s) {
    final a = Offset(s * 0.26, s * 0.68);
    final b = Offset(s * 0.5, s * 0.46);
    final c = Offset(s * 0.74, s * 0.3);

    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy),
      Paint()
        ..color = AppColors.brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Outer nodes are people; the middle one is the market they meet over.
    final node = Paint()..color = AppColors.brand;
    canvas.drawCircle(a, s * 0.085, node);
    canvas.drawCircle(c, s * 0.085, node);

    canvas.drawCircle(b, s * 0.13, Paint()..color = AppColors.bg);
    _candle(
      canvas,
      cx: b.dx,
      width: s * 0.088,
      bodyTop: b.dy - s * 0.07,
      bodyBottom: b.dy + s * 0.07,
      wickTop: b.dy - s * 0.115,
      wickBottom: b.dy + s * 0.115,
      color: AppColors.profit,
    );
  }

  // --- Circle --------------------------------------------------------------

  void _paintCircle(Canvas canvas, double s) {
    final center = Offset(s / 2, s * 0.5);
    final radius = s * 0.3;

    // Five people around the market. The gap at the bottom keeps it a
    // gathering rather than a closed ring.
    const count = 5;
    for (var i = 0; i < count; i++) {
      final t = -math.pi / 2 + (i - (count - 1) / 2) * 0.72;
      final p = Offset(
        center.dx + radius * math.cos(t),
        center.dy + radius * math.sin(t),
      );
      canvas.drawCircle(
        p,
        s * 0.062,
        Paint()
          ..color = i == (count - 1) ~/ 2
              ? AppColors.brand
              : AppColors.discipline,
      );
    }

    _candle(
      canvas,
      cx: center.dx,
      width: s * 0.15,
      bodyTop: s * 0.42,
      bodyBottom: s * 0.68,
      wickTop: s * 0.36,
      wickBottom: s * 0.74,
      color: AppColors.profit,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.mark != mark ||
      old.background != background ||
      old.progress != progress;
}
