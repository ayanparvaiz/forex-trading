import 'instrument.dart';

enum TradeDirection {
  buy('বাই', 'Long'),
  sell('সেল', 'Short');

  const TradeDirection(this.bn, this.en);
  final String bn;
  final String en;

  /// +1 for a long, -1 for a short. Multiplying by this turns a raw price
  /// difference into a profit in the trader's favour.
  int get sign => this == TradeDirection.buy ? 1 : -1;
}

enum TradeStatus { open, closed }

enum ExitReason {
  stopLoss('স্টপ লস', 'Stopped out'),
  takeProfit('টার্গেট', 'Target hit'),
  manual('নিজে বন্ধ', 'Closed manually');

  const ExitReason(this.bn, this.en);
  final String bn;
  final String en;

  String label(bool bangla) => bangla ? bn : en;
}

/// A rule the trader broke. These — not profit — drive the discipline score.
enum RuleViolation {
  riskTooHigh(
    bn: 'রিস্ক বেশি',
    en: 'Risk too high',
    bnWhy: 'পরিকল্পনার চেয়ে বেশি টাকা ঝুঁকিতে ফেলেছেন',
    enWhy: 'You put more money at risk than your own plan allows',
    weight: 30,
  ),
  noReason(
    bn: 'কারণ লেখেননি',
    en: 'No reason given',
    bnWhy: 'কেন ট্রেডটা নিয়েছেন সেটা লেখা নেই — পরে শেখার কিছু থাকবে না',
    enWhy: 'Nothing written down, so there is nothing to learn from later',
    weight: 15,
  ),
  poorRiskReward(
    bn: 'দুর্বল R:R',
    en: 'Poor R:R',
    bnWhy: 'রিস্কের তুলনায় টার্গেট ছোট — লম্বা দৌড়ে এই অঙ্ক হারে',
    enWhy: 'The target is small next to the risk — that maths loses long-term',
    weight: 15,
  ),
  movedStop(
    bn: 'স্টপ সরিয়েছেন',
    en: 'Moved the stop',
    bnWhy: 'লস বাড়ার দিকে স্টপ সরানো — অ্যাকাউন্ট শেষ হওয়ার এক নম্বর কারণ',
    enWhy: 'Widening a stop is the number one way accounts die',
    weight: 35,
  ),
  revengeTrade(
    bn: 'রিভেঞ্জ ট্রেড',
    en: 'Revenge trade',
    bnWhy: 'হারার সাথে সাথেই আবার ঢুকেছেন — এটা রাগ, প্ল্যান না',
    enWhy: 'You re-entered right after a loss — that is anger, not a plan',
    weight: 25,
  ),
  overtrading(
    bn: 'অতিরিক্ত ট্রেড',
    en: 'Overtrading',
    bnWhy: 'একদিনে অনেক বেশি ট্রেড — সেটআপের জন্য অপেক্ষা করেননি',
    enWhy: 'Too many trades in one day — you did not wait for the setup',
    weight: 20,
  ),
  noJournal(
    bn: 'জার্নাল লেখেননি',
    en: 'No journal entry',
    bnWhy: 'ট্রেড বন্ধ করে কী শিখলেন লেখেননি',
    enWhy: 'You closed the trade without writing what you learned',
    weight: 10,
  );

  const RuleViolation({
    required this.bn,
    required this.en,
    required this.bnWhy,
    required this.enWhy,
    required this.weight,
  });

  final String bn;
  final String en;
  final String bnWhy;
  final String enWhy;

  /// Penalty applied to the discipline score, before normalisation.
  final int weight;

  String label(bool bangla) => bangla ? bn : en;
  String why(bool bangla) => bangla ? bnWhy : enWhy;
}

/// A single demo trade, open or closed.
///
/// Prices are stored raw; every derived number (pips, risk, P&L, R) is computed
/// from the [Instrument] so JPY pairs and USD pairs both come out right.
class Trade {
  const Trade({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.lots,
    required this.entryPrice,
    required this.stopPrice,
    required this.targetPrice,
    required this.openedAt,
    required this.balanceAtEntry,
    required this.reason,
    this.closedAt,
    this.exitPrice,
    this.exitReason,
    this.lesson,
    this.violations = const {},
    this.isShared = false,
  });

  final String id;
  final String symbol;
  final TradeDirection direction;

  /// Position size in standard lots. 0.01 is one micro lot.
  final double lots;

  final double entryPrice;
  final double stopPrice;
  final double targetPrice;

  final DateTime openedAt;
  final DateTime? closedAt;
  final double? exitPrice;
  final ExitReason? exitReason;

  /// Account balance when the trade was opened — needed to express risk as a
  /// percentage after the fact, even once the balance has moved on.
  final double balanceAtEntry;

  /// Why the trader took it. Required before the order can be placed.
  final String reason;

  /// What they learned, written when closing.
  final String? lesson;

  final Set<RuleViolation> violations;
  final bool isShared;

  /// Everything needed to rebuild the trade, and nothing derived.
  ///
  /// Pips, risk, R and P&L are all computed from these, so storing them would
  /// only create a second copy that could drift from the first — and a journal
  /// whose numbers disagree with its own prices is worth nothing.
  Map<String, Object?> toJson() => {
    'symbol': symbol,
    'direction': direction.name,
    'lots': lots,
    'entryPrice': entryPrice,
    'stopPrice': stopPrice,
    'targetPrice': targetPrice,
    'openedAt': openedAt.toIso8601String(),
    'closedAt': closedAt?.toIso8601String(),
    'exitPrice': exitPrice,
    'exitReason': exitReason?.name,
    'balanceAtEntry': balanceAtEntry,
    'reason': reason,
    'lesson': lesson,
    'violations': [for (final v in violations) v.name],
    'isShared': isShared,
  };

  /// Rebuilds a trade from storage.
  ///
  /// [id] comes from outside the map because Firestore keeps it on the
  /// document rather than in the fields, and the two must never disagree.
  ///
  /// Unknown enum names are dropped rather than throwing: a violation renamed
  /// in a later version should cost that one flag, not the whole journal.
  factory Trade.fromJson(String id, Map<String, Object?> json) {
    DateTime? date(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;

    double number(Object? value, [double fallback = 0]) =>
        value is num ? value.toDouble() : fallback;

    return Trade(
      id: id,
      symbol: json['symbol'] as String? ?? '',
      direction: TradeDirection.values.firstWhere(
        (d) => d.name == json['direction'],
        orElse: () => TradeDirection.buy,
      ),
      lots: number(json['lots']),
      entryPrice: number(json['entryPrice']),
      stopPrice: number(json['stopPrice']),
      targetPrice: number(json['targetPrice']),
      openedAt: date(json['openedAt']) ?? DateTime.now(),
      closedAt: date(json['closedAt']),
      exitPrice: json['exitPrice'] is num
          ? (json['exitPrice'] as num).toDouble()
          : null,
      exitReason: ExitReason.values
          .where((r) => r.name == json['exitReason'])
          .firstOrNull,
      balanceAtEntry: number(json['balanceAtEntry']),
      reason: json['reason'] as String? ?? '',
      lesson: json['lesson'] as String?,
      violations: {
        for (final name in (json['violations'] as List? ?? const []))
          ...RuleViolation.values.where((v) => v.name == name),
      },
      isShared: json['isShared'] as bool? ?? false,
    );
  }

  Instrument get instrument => Instrument.bySymbol(symbol);

  TradeStatus get status =>
      closedAt == null ? TradeStatus.open : TradeStatus.closed;

  bool get isOpen => status == TradeStatus.open;

  /// Distance from entry to stop, in pips. This is the trade's risk unit — 1R.
  double get riskPips => instrument.pipsBetween(entryPrice, stopPrice);

  /// Distance from entry to target, in pips.
  double get rewardPips => instrument.pipsBetween(targetPrice, entryPrice);

  /// Reward-to-risk ratio, e.g. 2.0 means the target is twice the stop away.
  double get riskReward => riskPips == 0 ? 0 : rewardPips / riskPips;

  /// Money at risk if the stop is hit, before costs.
  double get riskAmount => riskPips * instrument.pipValuePerLot * lots;

  /// Risk as a percentage of the balance at entry.
  double get riskPercent =>
      balanceAtEntry == 0 ? 0 : riskAmount / balanceAtEntry * 100;

  /// Spread paid on entry. Charged once, immediately — which is why a trade
  /// starts slightly negative the moment it opens.
  double get spreadCost =>
      instrument.spreadPips * instrument.pipValuePerLot * lots;

  /// Overnight financing, charged per rollover the position survives.
  double get swapCost {
    final until = closedAt ?? DateTime.now();
    final nights = until.difference(openedAt).inDays;
    if (nights <= 0) return 0;
    final perNight = direction == TradeDirection.buy
        ? instrument.swapLongPerLot
        : instrument.swapShortPerLot;
    return perNight * lots * nights;
  }

  /// Gross profit at [price], before costs.
  double grossPnlAt(double price) {
    final pips = (price - entryPrice) * direction.sign / instrument.pipSize;
    return pips * instrument.pipValuePerLot * lots;
  }

  /// Profit at [price] after spread and swap — what actually hits the balance.
  double netPnlAt(double price) => grossPnlAt(price) - spreadCost + swapCost;

  /// Realised profit, or null while the trade is still open.
  double? get realisedPnl => exitPrice == null ? null : netPnlAt(exitPrice!);

  /// Result in R — the only unit that compares trades of different sizes.
  ///
  /// −1R means the stop was hit exactly; +2R means twice the risk was made.
  double? get rMultiple {
    final pnl = realisedPnl;
    if (pnl == null || riskAmount == 0) return null;
    return pnl / riskAmount;
  }

  double rMultipleAt(double price) =>
      riskAmount == 0 ? 0 : netPnlAt(price) / riskAmount;

  /// Price at which the position would be flat, accounting for the spread.
  double get breakEvenPrice {
    final pipsToRecover = lots == 0
        ? 0.0
        : spreadCost / (instrument.pipValuePerLot * lots);
    return instrument.shiftByPips(entryPrice, pipsToRecover * direction.sign);
  }

  Trade copyWith({
    DateTime? closedAt,
    double? exitPrice,
    ExitReason? exitReason,
    String? lesson,
    Set<RuleViolation>? violations,
    bool? isShared,
    double? stopPrice,
  }) {
    return Trade(
      id: id,
      symbol: symbol,
      direction: direction,
      lots: lots,
      entryPrice: entryPrice,
      stopPrice: stopPrice ?? this.stopPrice,
      targetPrice: targetPrice,
      openedAt: openedAt,
      balanceAtEntry: balanceAtEntry,
      reason: reason,
      closedAt: closedAt ?? this.closedAt,
      exitPrice: exitPrice ?? this.exitPrice,
      exitReason: exitReason ?? this.exitReason,
      lesson: lesson ?? this.lesson,
      violations: violations ?? this.violations,
      isShared: isShared ?? this.isShared,
    );
  }
}
