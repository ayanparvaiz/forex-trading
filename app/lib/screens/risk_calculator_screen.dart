import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/calculations.dart';
import '../data/session_controller.dart';
import '../models/instrument.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Opens the calculator, starting from [balance] and [instrument].
Future<void> openRiskCalculator(
  BuildContext context, {
  required double balance,
  Instrument? instrument,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        RiskCalculatorScreen(balance: balance, instrument: instrument),
  ),
);

/// Sizing a trade before taking it: how much to lose if wrong, how far the
/// stop is — and the size that follows, with what it costs and what it
/// could make.
///
/// The same arithmetic the trade screen uses ([sizePosition]), with nothing
/// placed: a place to ask "what if" without an order in the way.
class RiskCalculatorScreen extends StatefulWidget {
  const RiskCalculatorScreen({
    super.key,
    required this.balance,
    this.instrument,
  });

  final double balance;
  final Instrument? instrument;

  @override
  State<RiskCalculatorScreen> createState() => _RiskCalculatorScreenState();
}

class _RiskCalculatorScreenState extends State<RiskCalculatorScreen> {
  late Instrument _instrument = widget.instrument ?? Instrument.eurusd;
  late final _balance = TextEditingController(
    text: widget.balance.toStringAsFixed(0),
  );
  final _stop = TextEditingController(text: '20');
  double _riskPercent = 1;
  double _reward = 2;

  @override
  void dispose() {
    _balance.dispose();
    _stop.dispose();
    super.dispose();
  }

  double get _balanceValue => double.tryParse(_balance.text) ?? 0;
  double get _stopPips => double.tryParse(_stop.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    const entry = 100.0;
    final size = sizePosition(
      balance: _balanceValue,
      riskPercent: _riskPercent,
      entryPrice: entry,
      stopPrice: entry - _stopPips * _instrument.pipSize,
      instrument: _instrument,
    );
    final win = size.actualRisk * _reward;
    // Ten losses in a row at this risk: what is gone.
    final tenLost = 100 * (1 - _pow(1 - _riskPercent / 100, 10));

    return Scaffold(
      appBar: AppBar(title: Text(s.riskCalculator)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.riskCalculatorIntro,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            Gap.h16,
            Text(s.pair, style: Theme.of(context).textTheme.labelSmall),
            Gap.h8,
            Wrap(
              spacing: 8,
              children: [
                for (final i in Instrument.all)
                  ChoiceChip(
                    label: Text(i.symbol),
                    selected: _instrument == i,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _instrument = i),
                    backgroundColor: AppColors.elevated,
                    selectedColor: AppColors.brandDim,
                    side: BorderSide(
                      color: _instrument == i
                          ? AppColors.brand
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
            Gap.h16,
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _balance,
                    label: s.balance,
                    onChanged: () => setState(() {}),
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: _NumberField(
                    controller: _stop,
                    label: s.stopDistancePips,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
            Gap.h16,
            _SliderRow(
              label: s.riskPerTrade,
              value: '${_riskPercent.toStringAsFixed(2)}%',
              slider: Slider(
                value: _riskPercent,
                min: 0.25,
                max: 5,
                divisions: 19,
                activeColor: _riskPercent > 2
                    ? AppColors.loss
                    : AppColors.brand,
                onChanged: (v) => setState(() => _riskPercent = v),
              ),
            ),
            _SliderRow(
              label: s.rewardToRisk,
              value: '${_reward.toStringAsFixed(1)} : 1',
              slider: Slider(
                value: _reward,
                min: 1,
                max: 5,
                divisions: 8,
                activeColor: AppColors.brand,
                onChanged: (v) => setState(() => _reward = v),
              ),
            ),
            Gap.h8,
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.positionSize,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Gap.h4,
                  Text(
                    '${size.lots.toStringAsFixed(2)} ${s.lots}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  Gap.h12,
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: s.ifYouLose,
                          value: '−${pointsValue(size.actualRisk)}',
                          hint: '${size.actualRiskPercent.toStringAsFixed(2)}%',
                          valueColor: AppColors.loss,
                        ),
                      ),
                      Expanded(
                        child: StatTile(
                          label: s.ifYouWin,
                          value: '+${pointsValue(win)}',
                          hint: '${_reward.toStringAsFixed(1)}R',
                          valueColor: AppColors.profit,
                        ),
                      ),
                    ],
                  ),
                  Gap.h12,
                  Text(
                    s.pipValueLine(
                      pointsValue(_instrument.pipValuePerLot, decimals: 2),
                      pointsValue(
                        _instrument.pipValuePerLot * size.lots,
                        decimals: 2,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (size.isBelowMinimum && _stopPips > 0) ...[
              Gap.h12,
              _Note(
                color: AppColors.warning,
                text: s.belowMinimumLot(
                  '${_riskPercent.toStringAsFixed(2)}%',
                  size.exactLots.toStringAsFixed(4),
                  '${size.minimumLotRiskPercent.toStringAsFixed(2)}%',
                ),
              ),
            ],
            if (_riskPercent > 2) ...[
              Gap.h12,
              _Note(
                color: AppColors.loss,
                text: s.riskWarning(
                  '${_riskPercent.toStringAsFixed(2)}%',
                  '${tenLost.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static double _pow(double base, int times) {
    var out = 1.0;
    for (var i = 0; i < times; i++) {
      out *= base;
    }
    return out;
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => onChanged(),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.slider,
  });

  final String label;
  final String value;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelSmall),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
        slider,
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: Radii.tile,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.45, color: color),
      ),
    );
  }
}
