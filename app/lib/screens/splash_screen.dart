import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

/// The first Flutter frame, picking up where the native splash leaves off.
///
/// The native splash shows the same mark on the same background, so the handoff
/// is invisible: what the eye sees is a still logo that suddenly starts moving,
/// not two screens swapping. That only works because both are generated from
/// the same painter and share the exact background colour.
///
/// The intro runs once and then holds a slow breath, so a fast launch looks
/// deliberate rather than clipped, and a slow one never looks stuck.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.showWordmark = true});

  final bool showWordmark;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..forward();

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  /// The tile lands with a small overshoot — the difference between an app
  /// that feels alive and one that feels like a loading screen.
  late final Animation<double> _scale = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );

  /// Candles start rising once the bubble has arrived.
  late final Animation<double> _candles = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.28, 1, curve: Curves.linear),
  );

  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_intro, _breath]),
              builder: (context, _) {
                // Once the intro is done the logo keeps breathing, so a slow
                // start never reads as a frozen screen.
                final breathing = _intro.isCompleted
                    ? 1 + 0.025 * Curves.easeInOut.transform(_breath.value)
                    : 1.0;

                return Opacity(
                  opacity: _fade.value,
                  child: Transform.scale(
                    scale: (0.72 + 0.28 * _scale.value) * breathing,
                    child: AppLogo(size: 116, progress: _candles.value),
                  ),
                );
              },
            ),
            if (widget.showWordmark) ...[
              Gap.h24,
              AnimatedBuilder(
                animation: _wordmark,
                builder: (context, child) => Opacity(
                  opacity: _wordmark.value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - _wordmark.value)),
                    child: child,
                  ),
                ),
                child: const Text(
                  'Forex Social',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
