import 'package:flutter/material.dart';

import '../core/calculations.dart';
import '../data/account_scope.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/candle.dart';
import '../models/instrument.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';
import '../widgets/candle_chart.dart';
import '../widgets/common.dart';

/// Order ticket.
///
/// Built around one rule: the trader states what they are willing to lose and
/// why, and the size is derived. There is no field for "how many lots" — that
/// number is an output here, never an input.
class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  Instrument _instrument = Instrument.eurusd;
  Timeframe _timeframe = Timeframe.h1;
  TradeDirection _direction = TradeDirection.buy;

  /// Stop distance in pips. Entered as a distance, not a price — a beginner can
  /// reason about "20 pips away" long before they can about "1.08312".
  double _stopPips = 20;

  /// Target as a multiple of the stop.
  double _rewardRatio = 2;

  double _riskPercent = 1;

  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  double get _entryPrice {
    final store = AccountScope.of(context);
    return _direction == TradeDirection.buy
        ? store.market.ask(_instrument)
        : store.market.bid(_instrument);
  }

  double get _stopPrice =>
      _instrument.shiftByPips(_entryPrice, -_stopPips * _direction.sign);

  double get _targetPrice => _instrument.shiftByPips(
    _entryPrice,
    _stopPips * _rewardRatio * _direction.sign,
  );

  String _directionLabel(TradeDirection d, Strings s) =>
      d == TradeDirection.buy ? s.buy : s.sell;

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);
    final s = context.s;

    final size = sizePosition(
      balance: store.balance,
      riskPercent: _riskPercent,
      entryPrice: _entryPrice,
      stopPrice: _stopPrice,
      instrument: _instrument,
    );

    final reason = _reasonController.text;
    final violations = store.previewViolations(
      riskPercent: size.actualRiskPercent,
      riskReward: _rewardRatio,
      reason: reason,
    );

    final blocker = _blockingReason(size, reason, s);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navTrade),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.lg),
            child: Center(
              child: Text(
                pointsValue(store.balance),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 120),
        children: [
          _pairSelector(),
          Gap.h12,
          _chartCard(store.market.price(_instrument), s),
          Gap.h12,
          _directionToggle(s),
          Gap.h12,
          _planCard(size, s),
          Gap.h12,
          _sizeCard(size, s),
          Gap.h12,
          _reasonCard(s),
          if (violations.isNotEmpty) ...[
            Gap.h12,
            _violationsCard(violations, s),
          ],
        ],
      ),
      bottomNavigationBar: _placeBar(size, blocker, s),
    );
  }

  /// Why the order cannot be sent, or null when it can.
  ///
  /// Kept separate from rule *violations*: a violation is allowed through and
  /// costs discipline points, but these are hard stops.
  String? _blockingReason(PositionSize size, String reason, Strings s) {
    if (size.isBelowMinimum) return s.blockedBelowMinLot;
    if (!size.isTradable) return s.blockedZeroSize;
    if (reason.trim().length < 10) return s.blockedNoReason;
    return null;
  }

  Widget _pairSelector() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: Instrument.all.length,
        separatorBuilder: (_, _) => Gap.w8,
        itemBuilder: (context, i) {
          final instrument = Instrument.all[i];
          final selected = instrument.symbol == _instrument.symbol;
          return ChoiceChip(
            label: Text(instrument.symbol),
            selected: selected,
            onSelected: (_) => setState(() => _instrument = instrument),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.brandDim,
            side: BorderSide(
              color: selected ? AppColors.brand : AppColors.border,
            ),
          );
        },
      ),
    );
  }

  Widget _chartCard(double livePrice, Strings s) {
    final store = AccountScope.of(context);
    final candles = store.market.candles(_instrument, timeframe: _timeframe);

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.md, Gap.sm, Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
            child: Row(
              children: [
                Text(
                  _instrument.formatPrice(livePrice),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    fontFeatures: tabularFigures,
                  ),
                ),
                Gap.w8,
                Pill(
                  text: '${s.spread} ${_instrument.spreadPips}',
                  color: AppColors.warning,
                  dense: true,
                ),
                const Spacer(),
                for (final tf in Timeframe.values)
                  GestureDetector(
                    onTap: () => setState(() => _timeframe = tf),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        tf.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: tf == _timeframe
                              ? AppColors.brand
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Gap.h8,
          CandleChart(
            candles: candles,
            instrument: _instrument,
            entryPrice: _entryPrice,
            stopPrice: _stopPrice,
            targetPrice: _targetPrice,
            height: 250,
            entryLabel: s.entry,
            stopLabel: s.stopLoss,
            targetLabel: s.target,
            loadingLabel: s.chartLoading,
          ),
        ],
      ),
    );
  }

  Widget _directionToggle(Strings s) {
    return Row(
      children: [
        for (final d in TradeDirection.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _direction = d),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: _direction == d
                      ? (d == TradeDirection.buy
                            ? AppColors.profitDim
                            : AppColors.lossDim)
                      : AppColors.surface,
                  borderRadius: Radii.tile,
                  border: Border.all(
                    color: _direction == d
                        ? (d == TradeDirection.buy
                              ? AppColors.profit
                              : AppColors.loss)
                        : AppColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    _directionLabel(d, s),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _direction == d
                          ? (d == TradeDirection.buy
                                ? AppColors.profit
                                : AppColors.loss)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (d != TradeDirection.values.last) Gap.w12,
        ],
      ],
    );
  }

  Widget _planCard(PositionSize size, Strings s) {
    return SectionCard(
      title: s.plan,
      child: Column(
        children: [
          _slider(
            label: s.stopLoss,
            value: '${_stopPips.toStringAsFixed(0)} ${s.pips}',
            secondary: _instrument.formatPrice(_stopPrice),
            secondaryColor: AppColors.loss,
            slider: Slider(
              value: _stopPips,
              min: 5,
              max: 80,
              divisions: 75,
              onChanged: (v) => setState(() => _stopPips = v),
            ),
          ),
          _slider(
            label: '${s.target} (R:R)',
            value: '1 : ${_rewardRatio.toStringAsFixed(1)}',
            secondary: _instrument.formatPrice(_targetPrice),
            secondaryColor: AppColors.profit,
            slider: Slider(
              value: _rewardRatio,
              min: 0.5,
              max: 5,
              divisions: 45,
              onChanged: (v) => setState(() => _rewardRatio = v),
            ),
          ),
          _slider(
            label: s.risk,
            value: '${_riskPercent.toStringAsFixed(2)}%',
            secondary: pointsDelta(-size.plannedRisk),
            secondaryColor: AppColors.loss,
            slider: Slider(
              value: _riskPercent,
              min: 0.25,
              max: 5,
              divisions: 19,
              onChanged: (v) => setState(() => _riskPercent = v),
            ),
          ),
          if (_riskPercent > 2) ...[
            Gap.h8,
            _Warning(
              color: AppColors.loss,
              text: s.riskWarning(
                '${_riskPercent.toStringAsFixed(2)}%',
                '${(100 * (1 - _survivalFactor(10))).toStringAsFixed(0)}%',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Fraction of the balance left after [n] consecutive full-risk losses.
  double _survivalFactor(int n) {
    var remaining = 1.0;
    for (var i = 0; i < n; i++) {
      remaining *= 1 - _riskPercent / 100;
    }
    return remaining;
  }

  Widget _slider({
    required String label,
    required String value,
    required String secondary,
    required Color secondaryColor,
    required Widget slider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: tabularFigures,
              ),
            ),
            Gap.w8,
            Pill(text: secondary, color: secondaryColor, dense: true),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: slider,
        ),
      ],
    );
  }

  Widget _sizeCard(PositionSize size, Strings s) {
    return SectionCard(
      title: s.calculation,
      trailing: Pill(text: s.sizeFromRisk, color: AppColors.brand, dense: true),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: s.positionSize,
                  value: '${size.lots.toStringAsFixed(2)} ${s.lots}',
                  hint:
                      '${(size.lots * Instrument.contractSize).toStringAsFixed(0)} ${s.units}',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.ifYouLose,
                  value: pointsDelta(-size.actualRisk),
                  hint: '${size.actualRiskPercent.toStringAsFixed(2)}%',
                  valueColor: AppColors.loss,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.ifYouWin,
                  value: pointsDelta(size.actualRisk * _rewardRatio),
                  hint:
                      '${(size.actualRiskPercent * _rewardRatio).toStringAsFixed(2)}%',
                  valueColor: AppColors.profit,
                ),
              ),
            ],
          ),
          if (size.isBelowMinimum) ...[
            Gap.h16,
            _Warning(
              color: AppColors.warning,
              text: s.belowMinimumLot(
                '${_riskPercent.toStringAsFixed(2)}%',
                size.exactLots.toStringAsFixed(4),
                '${size.minimumLotRiskPercent.toStringAsFixed(2)}%',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reasonCard(Strings s) {
    return SectionCard(
      title: s.whyThisTrade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _reasonController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, height: 1.4),
            decoration: InputDecoration(hintText: s.whyHint),
            onChanged: (_) => setState(() {}),
          ),
          Gap.h8,
          Text(
            s.whyFootnote,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _violationsCard(Set<RuleViolation> violations, Strings s) {
    return SectionCard(
      title: s.breakingRules,
      trailing: Pill(
        text: s.pointsPenalty(
          violations.fold<int>(0, (sum, v) => sum + v.weight),
        ),
        color: AppColors.loss,
        dense: true,
      ),
      child: Column(
        children: [
          for (final v in violations)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.loss,
                  ),
                  Gap.w8,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.label(s.isBangla),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          v.why(s.isBangla),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Gap.h4,
          Text(
            s.violationsAllowed,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _placeBar(PositionSize size, String? blocker, Strings s) {
    final enabled = blocker == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!enabled) ...[
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                Gap.w8,
                Expanded(
                  child: Text(
                    blocker,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            Gap.h8,
          ],
          FilledButton(
            onPressed: enabled ? () => _place(size, s) : null,
            style: FilledButton.styleFrom(
              backgroundColor: _direction == TradeDirection.buy
                  ? AppColors.profit
                  : AppColors.loss,
              foregroundColor: Colors.white,
            ),
            child: Text(
              '${_directionLabel(_direction, s)} · '
              '${size.lots.toStringAsFixed(2)} ${s.lots} · '
              '${s.risk} ${pointsDelta(-size.actualRisk)}',
            ),
          ),
        ],
      ),
    );
  }

  void _place(PositionSize size, Strings s) {
    final store = AccountScope.of(context);

    store.openTrade(
      instrument: _instrument,
      direction: _direction,
      lots: size.lots,
      stopPrice: _stopPrice,
      targetPrice: _targetPrice,
      reason: _reasonController.text.trim(),
    );

    _reasonController.clear();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.tradeOpened(
            _instrument.symbol,
            _directionLabel(_direction, s),
            _stopPips.toStringAsFixed(0),
          ),
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: Radii.tile,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 17, color: color),
          Gap.w8,
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
