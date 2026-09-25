import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/models/trade_preset.dart';

/// The presets are the trade screen's answer to "three sliders is too many
/// decisions", so what has to hold is that they are a coherent set and that
/// the screen can always tell which one — if any — is showing.
void main() {
  test('careful risks less than standard, which risks less than bold', () {
    expect(
      TradePreset.careful.riskPercent,
      lessThan(TradePreset.standard.riskPercent),
    );
    expect(
      TradePreset.standard.riskPercent,
      lessThan(TradePreset.bold.riskPercent),
    );
  });

  test('no preset lands in the range the app warns about', () {
    // The screen warns above 2%. A one-tap button that puts someone straight
    // into the range the app calls dangerous would be the app arguing with
    // itself — past 2% has to be dragged there deliberately.
    for (final preset in TradePreset.values) {
      expect(preset.riskPercent, lessThanOrEqualTo(2));
    }
  });

  test('a smaller risk survives more losses', () {
    expect(
      TradePreset.careful.survival(10),
      greaterThan(TradePreset.bold.survival(10)),
    );

    // 1% ten times over is not 10%: 0.99^10 leaves just over 90%.
    expect(TradePreset.standard.survival(10), closeTo(0.904, 0.001));
  });

  test('matching finds the preset the numbers describe', () {
    for (final preset in TradePreset.values) {
      expect(
        TradePreset.matching(
          stopPips: preset.stopPips,
          rewardRatio: preset.rewardRatio,
          riskPercent: preset.riskPercent,
        ),
        preset,
      );
    }
  });

  test('matching survives the reward slider arriving off by a float', () {
    // The slider steps by 0.1 from 0.5, and twenty of those do not land on
    // exactly 2.5. An exact comparison would leave "careful" looking
    // unselected the instant it was selected.
    var reward = 0.5;
    for (var i = 0; i < 20; i++) {
      reward += 0.1;
    }

    expect(reward, isNot(2.5), reason: 'the float drift this test exists for');
    expect(
      TradePreset.matching(stopPips: 25, rewardRatio: reward, riskPercent: 0.5),
      TradePreset.careful,
    );
  });

  test('changing one number away from a preset makes it custom', () {
    // Derived, never remembered: a stored "careful" could otherwise disagree
    // with sliders that no longer say careful.
    expect(
      TradePreset.matching(stopPips: 25, rewardRatio: 2.5, riskPercent: 1.75),
      isNull,
    );
    expect(
      TradePreset.matching(stopPips: 40, rewardRatio: 2, riskPercent: 1),
      isNull,
    );
  });
}
