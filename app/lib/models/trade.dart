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
  stopLoss('স্টপ লস'),
  takeProfit('টার্গেট'),
  manual('নিজে বন্ধ');

  const ExitReason(this.bn);
  final String bn;
}

/// A rule the trader broke. These — not profit — drive the discipline score.
enum RuleViolation {
  riskTooHigh(
    'রিস্ক বেশি',
    'পরিকল্পনার চেয়ে বেশি টাকা ঝুঁকিতে ফেলেছেন',
    weight: 30,
  ),
  noReason(
    'কারণ লেখেননি',
    'কেন ট্রেডটা নিয়েছেন সেটা লেখা নেই — পরে শেখার কিছু থাকবে না',
    weight: 15,
  ),
  poorRiskReward(
    'দুর্বল R:R',
    'রিস্কের তুলনায় টার্গেট ছোট — লম্বা দৌড়ে এই অঙ্ক হারে',
    weight: 15,
  ),
  movedStop(
    'স্টপ সরিয়েছেন',
    'লস বাড়ার দিকে স্টপ সরানো — অ্যাকাউন্ট শেষ হওয়ার এক নম্বর কারণ',
    weight: 35,
  ),
  revengeTrade(
    'রিভেঞ্জ ট্রেড',
    'হারার সাথে সাথেই আবার ঢুকেছেন — এটা রাগ, প্ল্যান না',
    weight: 25,
  ),
  overtrading(
    'অতিরিক্ত ট্রেড',
    'একদিনে অনেক বেশি ট্রেড — সেটআপের জন্য অপেক্ষা করেননি',
    weight: 20,
  ),
  noJournal(
    'জার্নাল লেখেননি',
    'ট্রেড বন্ধ করে কী শিখলেন লেখেননি',
    weight: 10,
  );

  const RuleViolation(this.bn, this.explanation, {required this.weight});

  final String bn;
  final String explanation;

  /// Penalty applied to the discipline score, before normalisation.
  final int weight;
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
  double? get realisedPnl =>
      exitPrice == null ? null : netPnlAt(exitPrice!);

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
    final pipsToRecover =
        lots == 0 ? 0.0 : spreadCost / (instrument.pipValuePerLot * lots);
    return instrument.shiftByPips(
      entryPrice,
      pipsToRecover * direction.sign,
    );
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
