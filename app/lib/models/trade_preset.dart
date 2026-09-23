import 'dart:math' as math;

/// A whole plan in one tap: stop distance, target and risk together.
///
/// These three numbers only mean anything as a set, which is the thing a
/// beginner gets wrong first — a tight stop with a large risk is not "careful"
/// because the stop is tight. So they move together, and the sliders
/// underneath are for someone who already knows why they want something else.
enum TradePreset {
  careful(stopPips: 25, rewardRatio: 2.5, riskPercent: 0.5),
  standard(stopPips: 20, rewardRatio: 2, riskPercent: 1),

  /// Stops at 2%, which is exactly where the app starts warning.
  ///
  /// Anything past that has to be dragged there on purpose. A button that puts
  /// someone one tap inside the range the app itself calls dangerous would be
  /// the app arguing with itself.
  bold(stopPips: 15, rewardRatio: 1.5, riskPercent: 2);

  const TradePreset({
    required this.stopPips,
    required this.rewardRatio,
    required this.riskPercent,
  });

  final double stopPips;
  final double rewardRatio;
  final double riskPercent;

  /// Fraction of the balance left after [n] consecutive full-risk losses.
  ///
  /// The number that makes the choice real. "Bold" means nothing on its own;
  /// "82% left after ten losses in a row" is a thing somebody can decide about.
  double survival(int n) => math.pow(1 - riskPercent / 100, n).toDouble();

  /// The preset these numbers describe, or null once one has been changed.
  ///
  /// Derived rather than remembered, so a stored "careful" can never disagree
  /// with sliders that no longer say careful.
  static TradePreset? matching({
    required double stopPips,
    required double rewardRatio,
    required double riskPercent,
  }) {
    for (final preset in values) {
      if (_near(preset.stopPips, stopPips) &&
          _near(preset.rewardRatio, rewardRatio) &&
          _near(preset.riskPercent, riskPercent)) {
        return preset;
      }
    }
    return null;
  }

  /// Compared with a tolerance, not with ==.
  ///
  /// The reward slider steps by 0.1, and in binary floating point twenty of
  /// those do not land on exactly 2.5. An exact comparison would leave the
  /// preset looking unselected the instant it was selected.
  static bool _near(double a, double b) => (a - b).abs() < 0.001;
}
