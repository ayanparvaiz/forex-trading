import 'package:flutter/material.dart';

import '../core/calculations.dart';
import '../data/account_scope.dart';
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

  double get _stopPrice => _instrument.shiftByPips(
        _entryPrice,
        -_stopPips * _direction.sign,
      );

  double get _targetPrice => _instrument.shiftByPips(
        _entryPrice,
        _stopPips * _rewardRatio * _direction.sign,
      );

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context);

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

    final blocker = _blockingReason(size, reason);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ট্রেড'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.lg),
            child: Center(
              child: Text(
                '\$${store.balance.toStringAsFixed(2)}',
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
          _chartCard(store.market.price(_instrument)),
          Gap.h12,
          _directionToggle(),
          Gap.h12,
          _planCard(size),
          Gap.h12,
          _sizeCard(size),
          Gap.h12,
          _reasonCard(),
          if (violations.isNotEmpty) ...[
            Gap.h12,
            _violationsCard(violations),
          ],
        ],
      ),
      bottomNavigationBar: _placeBar(size, blocker),
    );
  }

  /// Why the order cannot be sent, or null when it can.
  ///
  /// Kept separate from rule *violations*: a violation is allowed through and
  /// costs discipline points, but these are hard stops.
  String? _blockingReason(PositionSize size, String reason) {
    if (size.isBelowMinimum) {
      return 'এই রিস্কে সাইজ সর্বনিম্ন লটের চেয়ে ছোট';
    }
    if (!size.isTradable) {
      return 'পজিশন সাইজ শূন্য';
    }
    if (reason.trim().length < 10) {
      return 'কেন ট্রেডটা নিচ্ছেন লিখুন (অন্তত ১০ অক্ষর)';
    }
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

  Widget _chartCard(double livePrice) {
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
                  text: 'স্প্রেড ${_instrument.spreadPips} পিপ',
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
          ),
        ],
      ),
    );
  }

  Widget _directionToggle() {
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
                    d.bn,
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

  Widget _planCard(PositionSize size) {
    return SectionCard(
      title: 'প্ল্যান',
      child: Column(
        children: [
          _slider(
            label: 'স্টপ লস',
            value: '${_stopPips.toStringAsFixed(0)} পিপ',
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
            label: 'টার্গেট (R:R)',
            value: '১ : ${_rewardRatio.toStringAsFixed(1)}',
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
            label: 'রিস্ক',
            value: '${_riskPercent.toStringAsFixed(2)}%',
            secondary: money(-size.plannedRisk),
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
              text: 'ট্রেডে ${_riskPercent.toStringAsFixed(2)}% রিস্ক নিলে '
                  'টানা ১০টা হারলে অ্যাকাউন্টের '
                  '${(100 * (1 - _survivalFactor(10))).toStringAsFixed(0)}% '
                  'চলে যাবে। পেশাদাররা ১%-এর নিচে রাখেন।',
              color: AppColors.loss,
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

  Widget _sizeCard(PositionSize size) {
    return SectionCard(
      title: 'হিসাব',
      trailing: const Pill(
        text: 'রিস্ক থেকে সাইজ',
        color: AppColors.brand,
        dense: true,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'পজিশন সাইজ',
                  value: '${size.lots.toStringAsFixed(2)} লট',
                  hint: '${(size.lots * Instrument.contractSize).toStringAsFixed(0)} ইউনিট',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'হারলে',
                  value: money(-size.actualRisk),
                  hint: '${size.actualRiskPercent.toStringAsFixed(2)}%',
                  valueColor: AppColors.loss,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'জিতলে',
                  value: money(size.actualRisk * _rewardRatio),
                  hint: '${(size.actualRiskPercent * _rewardRatio).toStringAsFixed(2)}%',
                  valueColor: AppColors.profit,
                ),
              ),
            ],
          ),
          if (size.isBelowMinimum) ...[
            Gap.h16,
            _Warning(
              color: AppColors.warning,
              text: 'এই অ্যাকাউন্টে ${_riskPercent.toStringAsFixed(2)}% রিস্কে '
                  'সাইজ হয় ${size.exactLots.toStringAsFixed(4)} লট — কিন্তু ব্রোকারের '
                  'সর্বনিম্ন সাইজ ০.০১ লট। সেটা নিলে রিস্ক দাঁড়াবে '
                  '${size.minimumLotRiskPercent.toStringAsFixed(2)}%।\n\n'
                  'এটাই ছোট অ্যাকাউন্টের আসল সমস্যা — বেশিরভাগ অ্যাপ এটা লুকায়। '
                  'সমাধান: স্টপ কাছে আনুন, নয়তো ব্যালেন্স বাড়ান।',
            ),
          ],
        ],
      ),
    );
  }

  Widget _reasonCard() {
    return SectionCard(
      title: 'কেন এই ট্রেড?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _reasonController,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, height: 1.4),
            decoration: const InputDecoration(
              hintText: 'যেমন: H4 সাপোর্টে বুলিশ এনগাল্ফিং, ভলিউম কনফার্ম করেছে',
            ),
            onChanged: (_) => setState(() {}),
          ),
          Gap.h8,
          const Text(
            'ছয় মাস পর এই লেখাটাই বলে দেবে আপনি ট্রেডার নাকি জুয়াড়ি ছিলেন।',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _violationsCard(Set<RuleViolation> violations) {
    return SectionCard(
      title: 'নিয়ম ভাঙছেন',
      trailing: Pill(
        text: '−${violations.fold<int>(0, (s, v) => s + v.weight)} পয়েন্ট',
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
                  const Icon(Icons.error_outline,
                      size: 16, color: AppColors.loss),
                  Gap.w8,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.bn,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          v.explanation,
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
          const Text(
            'ট্রেডটা আটকানো হবে না — কিন্তু ডিসিপ্লিন স্কোরে যোগ হবে।',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _placeBar(PositionSize size, String? blocker) {
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
                const Icon(Icons.lock_outline,
                    size: 15, color: AppColors.textMuted),
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
            onPressed: enabled ? () => _place(size) : null,
            style: FilledButton.styleFrom(
              backgroundColor: _direction == TradeDirection.buy
                  ? AppColors.profit
                  : AppColors.loss,
              foregroundColor: Colors.white,
            ),
            child: Text(
              '${_direction.bn} · ${size.lots.toStringAsFixed(2)} লট · '
              'রিস্ক ${money(-size.actualRisk)}',
            ),
          ),
        ],
      ),
    );
  }

  void _place(PositionSize size) {
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
          '${_instrument.symbol} ${_direction.bn} খোলা হয়েছে · '
          'স্টপ ${_stopPips.toStringAsFixed(0)} পিপ',
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
