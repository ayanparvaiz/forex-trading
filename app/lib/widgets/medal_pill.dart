import 'package:flutter/material.dart';

/// The gold, silver and bronze tag on the top three leaderboard rows.
///
/// Carries the discipline score, not a prize. The design this follows showed
/// cash amounts, and the app awards none — putting a dollar figure here would
/// be a claim with nothing behind it, and it would say the opposite of the
/// line above the board: this list is not ranked by money.
class MedalPill extends StatelessWidget {
  const MedalPill({super.key, required this.place, required this.label});

  /// 1, 2 or 3.
  final int place;
  final String label;

  static const _tiers = {
    1: _Tier(
      light: Color(0xFFFFD66B),
      dark: Color(0xFFF29D12),
      disc: Color(0xFFFFE08A),
      rim: Color(0xFFD9820A),
      ink: Color(0xFF7A4A00),
    ),
    // A shade darker than true silver: white type on a pale grey is the one
    // combination here that went unreadable on a small screen.
    2: _Tier(
      light: Color(0xFFCDD5DF),
      dark: Color(0xFF8391A3),
      disc: Color(0xFFF2F5F8),
      rim: Color(0xFF8D98A6),
      ink: Color(0xFF4A5462),
    ),
    3: _Tier(
      light: Color(0xFFF2A777),
      dark: Color(0xFFC25E2C),
      disc: Color(0xFFF7BF98),
      rim: Color(0xFFA64E22),
      ink: Color(0xFF6B2E0E),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final tier = _tiers[place] ?? _tiers[3]!;
    // The number on the medal is painted, not a Text widget, so it does not
    // inherit the app's font by itself. Handed down explicitly, it matches the
    // label beside it whatever font the app is set in.
    final family = DefaultTextStyle.of(context).style.fontFamily;

    return Semantics(
      label: 'Place $place, discipline $label',
      excludeSemantics: true,
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 5, right: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tier.light, tier.dark],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: tier.dark.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          // The gloss across the top half.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.white.withValues(alpha: 0.30),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 28,
              child: CustomPaint(painter: _MedalPainter(place, tier, family)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
                shadows: [
                  Shadow(
                    color: Color(0x73000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tier {
  const _Tier({
    required this.light,
    required this.dark,
    required this.disc,
    required this.rim,
    required this.ink,
  });

  final Color light;
  final Color dark;
  final Color disc;
  final Color rim;
  final Color ink;
}

/// A round medal hanging from a two-tailed ribbon, with the place on it.
class _MedalPainter extends CustomPainter {
  _MedalPainter(this.place, this.tier, this.fontFamily);

  final int place;
  final _Tier tier;
  final String? fontFamily;

  static const _ribbon = Color(0xFFE8468F);
  static const _ribbonShade = Color(0xFFB42C6E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, size.height * 0.62);
    final radius = w * 0.40;

    // Ribbon tails, drawn first so the disc sits over where they meet.
    final left = Path()
      ..moveTo(w * 0.18, 0)
      ..lineTo(w * 0.42, 0)
      ..lineTo(w * 0.56, center.dy - radius * 0.5)
      ..lineTo(w * 0.34, center.dy - radius * 0.5)
      ..close();
    final right = Path()
      ..moveTo(w * 0.58, 0)
      ..lineTo(w * 0.82, 0)
      ..lineTo(w * 0.66, center.dy - radius * 0.5)
      ..lineTo(w * 0.44, center.dy - radius * 0.5)
      ..close();
    canvas
      ..drawPath(right, Paint()..color = _ribbonShade)
      ..drawPath(left, Paint()..color = _ribbon);

    // Disc: a darker rim, then a lighter face.
    canvas
      ..drawCircle(center, radius, Paint()..color = tier.rim)
      ..drawCircle(
        center,
        radius * 0.78,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [Colors.white, tier.disc],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );

    final text = TextPainter(
      text: TextSpan(
        text: '$place',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: radius * 1.05,
          fontWeight: FontWeight.w900,
          color: tier.ink,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.place != place || old.fontFamily != fontFamily;
}
