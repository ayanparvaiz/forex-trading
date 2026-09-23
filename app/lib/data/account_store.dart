import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/calculations.dart';
import '../models/badge.dart';
import '../models/instrument.dart';
import '../models/trade.dart';
import 'mock_market.dart';

/// Everything about the learner's demo account: points, positions, history.
///
/// The account is a daily contest. Everyone is handed the same 10,000 points at
/// midnight and everyone starts level, so nobody can buy an advantage by
/// grinding yesterday — the only thing that carries over is the badge ladder.
///
/// Held in memory for now. The Firestore-backed version keeps the same API, so
/// the screens will not change when it lands.
class AccountStore extends ChangeNotifier {
  AccountStore({MockMarket? market}) : market = market ?? MockMarket() {
    _seedHistory();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      this.market.tick();
      _settleHitOrders();
      notifyListeners();
    });
  }

  final MockMarket market;
  Timer? _ticker;

  /// Points every trader is given at midnight. Not earned, not saved up.
  static const double dailyAllowance = 10000;

  /// The trader's own risk rule. Everything else is measured against it.
  double maxRiskPercent = 1.0;
  double minRiskReward = 1.5;
  int maxTradesPerDay = 3;

  final List<Trade> _trades = [];
  List<Trade> get trades => List.unmodifiable(_trades);

  List<Trade> get openTrades => _trades.where((t) => t.isOpen).toList();

  List<Trade> get closedTrades {
    final closed = _trades.where((t) => !t.isOpen).toList()
      ..sort((a, b) => b.closedAt!.compareTo(a.closedAt!));
    return closed;
  }

  /// Midnight that started the current trading day.
  ///
  /// Deriving the reset from the date rather than running a timer means the
  /// balance is correct even if the app was closed when midnight passed.
  DateTime get dayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Trades closed since the last reset. Only these move today's balance.
  List<Trade> get todaysClosedTrades =>
      closedTrades.where((t) => !t.closedAt!.isBefore(dayStart)).toList();

  /// Today's points: the allowance plus whatever today's closed trades did.
  double get balance =>
      dailyAllowance +
      todaysClosedTrades.fold<double>(
        0,
        (sum, t) => sum + (t.realisedPnl ?? 0),
      );

  /// Balance plus the floating result of anything still open.
  double get equity =>
      balance +
      openTrades.fold<double>(
        0,
        (sum, t) => sum + t.netPnlAt(market.price(t.instrument)),
      );

  double get openPnl => equity - balance;

  /// Result for the day so far, in points.
  double get todaysPnl => equity - dailyAllowance;

  /// Time left before the allowance resets.
  Duration get untilReset =>
      dayStart.add(const Duration(days: 1)).difference(DateTime.now());

  TradeStats get stats =>
      TradeStats.from(_trades, startingBalance: dailyAllowance);

  DisciplineBreakdown get discipline => calculateDiscipline(_trades);

  /// Net winning trades across every day played.
  ///
  /// This is the one number that survives the midnight reset, which is what
  /// makes the ladder worth climbing.
  int get badgePoints {
    var points = 0;
    for (final trade in _trades) {
      if (trade.isOpen) continue;
      points += (trade.realisedPnl ?? 0) > 0 ? 1 : -1;
    }
    return points;
  }

  BadgeRank get badge => BadgeRank.of(badgePoints);

  /// Rules this order would break, checked before it is allowed through.
  Set<RuleViolation> previewViolations({
    required double riskPercent,
    required double riskReward,
    required String reason,
  }) {
    return detectEntryViolations(
      riskPercent: riskPercent,
      riskReward: riskReward,
      reason: reason,
      recentTrades: _trades,
      now: DateTime.now(),
      maxRiskPercent: maxRiskPercent,
      minRiskReward: minRiskReward,
      maxTradesPerDay: maxTradesPerDay,
    );
  }

  /// Opens a position. The caller has already sized it from a risk percentage.
  Trade openTrade({
    required Instrument instrument,
    required TradeDirection direction,
    required double lots,
    required double stopPrice,
    required double targetPrice,
    required String reason,
  }) {
    // Fill at the spread-adjusted price, the way a real broker does: buys fill
    // at the ask, sells at the bid.
    final entry = direction == TradeDirection.buy
        ? market.ask(instrument)
        : market.bid(instrument);

    final trade = Trade(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      symbol: instrument.symbol,
      direction: direction,
      lots: lots,
      entryPrice: entry,
      stopPrice: stopPrice,
      targetPrice: targetPrice,
      openedAt: DateTime.now(),
      balanceAtEntry: balance,
      reason: reason,
    );

    final violations = previewViolations(
      riskPercent: trade.riskPercent,
      riskReward: trade.riskReward,
      reason: reason,
    );

    final recorded = trade.copyWith(violations: violations);
    _trades.add(recorded);

    // The crowd sees the order flow: one more buyer nudges the price up.
    market.applyPressure(instrument, direction == TradeDirection.buy ? 1 : -1);

    notifyListeners();
    return recorded;
  }

  /// Closes a position at the current market price.
  void closeTrade(String id, {String? lesson}) {
    final index = _trades.indexWhere((t) => t.id == id);
    if (index < 0 || !_trades[index].isOpen) return;

    final trade = _trades[index];
    final exit = trade.direction == TradeDirection.buy
        ? market.bid(trade.instrument)
        : market.ask(trade.instrument);

    _trades[index] = _closeWith(
      trade,
      exit: exit,
      reason: ExitReason.manual,
      lesson: lesson,
    );

    // Closing a long is a sell, and pushes the other way.
    market.applyPressure(
      trade.instrument,
      trade.direction == TradeDirection.buy ? -1 : 1,
    );

    notifyListeners();
  }

  /// Moving a stop further from entry is the single most account-destroying
  /// habit there is, so it is allowed — and recorded as a violation.
  void moveStop(String id, double newStop) {
    final index = _trades.indexWhere((t) => t.id == id);
    if (index < 0 || !_trades[index].isOpen) return;

    final trade = _trades[index];
    final wasRisk = trade.riskPips;
    final updated = trade.copyWith(stopPrice: newStop);

    _trades[index] = updated.riskPips > wasRisk
        ? updated.copyWith(
            violations: {...trade.violations, RuleViolation.movedStop},
          )
        : updated;
    notifyListeners();
  }

  void addLesson(String id, String lesson) {
    final index = _trades.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final trade = _trades[index];
    _trades[index] = trade.copyWith(
      lesson: lesson,
      violations: {...trade.violations}..remove(RuleViolation.noJournal),
    );
    notifyListeners();
  }

  void shareTrade(String id) {
    final index = _trades.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _trades[index] = _trades[index].copyWith(isShared: true);
    notifyListeners();
  }

  /// Fills stops and targets that the live price has reached.
  void _settleHitOrders() {
    for (var i = 0; i < _trades.length; i++) {
      final trade = _trades[i];
      if (!trade.isOpen) continue;

      final price = market.price(trade.instrument);
      final isLong = trade.direction == TradeDirection.buy;

      final stopHit = isLong
          ? price <= trade.stopPrice
          : price >= trade.stopPrice;
      final targetHit = isLong
          ? price >= trade.targetPrice
          : price <= trade.targetPrice;

      if (stopHit) {
        _trades[i] = _closeWith(
          trade,
          exit: trade.stopPrice,
          reason: ExitReason.stopLoss,
        );
      } else if (targetHit) {
        _trades[i] = _closeWith(
          trade,
          exit: trade.targetPrice,
          reason: ExitReason.takeProfit,
        );
      }
    }
  }

  Trade _closeWith(
    Trade trade, {
    required double exit,
    required ExitReason reason,
    String? lesson,
  }) {
    final violations = {...trade.violations};
    if (lesson == null || lesson.trim().isEmpty) {
      violations.add(RuleViolation.noJournal);
    }
    return trade.copyWith(
      closedAt: DateTime.now(),
      exitPrice: exit,
      exitReason: reason,
      lesson: lesson,
      violations: violations,
    );
  }

  /// A short history so the journal, stats and badge have something to show.
  void _seedHistory() {
    final now = DateTime.now();
    final seeds = <Map<String, dynamic>>[
      {
        'sym': 'EUR/USD',
        'dir': TradeDirection.buy,
        'entry': 1.08420,
        'stop': 1.08220,
        'target': 1.08820,
        'exit': 1.08820,
        'daysAgo': 9,
        'reason': 'H4 সাপোর্টে বুলিশ এনগাল্ফিং, লন্ডন সেশনের শুরুতে',
        'lesson':
            'প্ল্যান মতো চলেছে। টার্গেটে বসে থেকেছি, তাড়াতাড়ি বের হইনি।',
        'v': <RuleViolation>{},
      },
      {
        'sym': 'GBP/USD',
        'dir': TradeDirection.sell,
        'entry': 1.26800,
        'stop': 1.27000,
        'target': 1.26400,
        'exit': 1.27000,
        'daysAgo': 8,
        'reason': 'রেজিস্ট্যান্স রিজেকশন, ডেইলি ডাউনট্রেন্ড',
        'lesson':
            'স্টপ লেগেছে, ঠিক আছে। সেটআপ ভালো ছিল, ফল খারাপ — এটাই ট্রেডিং।',
        'v': <RuleViolation>{},
      },
      {
        'sym': 'EUR/USD',
        'dir': TradeDirection.buy,
        'entry': 1.08300,
        'stop': 1.08150,
        'target': 1.08450,
        'exit': 1.08150,
        'daysAgo': 6,
        'reason': 'মনে হলো উঠবে',
        'lesson': null,
        'v': <RuleViolation>{
          RuleViolation.noReason,
          RuleViolation.poorRiskReward,
          RuleViolation.noJournal,
        },
      },
      {
        'sym': 'USD/JPY',
        'dir': TradeDirection.buy,
        'entry': 150.200,
        'stop': 149.900,
        'target': 150.800,
        'exit': 150.800,
        'daysAgo': 5,
        'reason': 'ডেইলি ব্রেকআউট রিটেস্ট, ভলিউম কনফার্ম করেছে',
        'lesson':
            'রিটেস্টের জন্য অপেক্ষা করাটা কাজে দিয়েছে। ব্রেকআউটে ঝাঁপ দিইনি।',
        'v': <RuleViolation>{},
      },
      {
        'sym': 'EUR/USD',
        'dir': TradeDirection.sell,
        'entry': 1.08700,
        'stop': 1.08900,
        'target': 1.08300,
        'exit': 1.08900,
        'daysAgo': 3,
        'reason': 'আগের ট্রেডে হেরেছি, টাকা ফেরত আনতে হবে',
        'lesson': 'রাগের মাথায় ঢুকেছিলাম। এটা ট্রেড ছিল না, প্রতিশোধ ছিল।',
        'v': <RuleViolation>{
          RuleViolation.revengeTrade,
          RuleViolation.riskTooHigh,
        },
      },
      {
        'sym': 'GBP/USD',
        'dir': TradeDirection.buy,
        'entry': 1.26300,
        'stop': 1.26100,
        'target': 1.26750,
        'exit': 1.26750,
        'daysAgo': 1,
        'reason': 'ডেইলি ডিমান্ড জোন, ১৫মি তে কনফার্মেশন ক্যান্ডেল',
        'lesson':
            'রিস্ক ১% এর নিচে রেখেছি, সাইজ ঠিক ছিল। এভাবেই চালিয়ে যেতে হবে।',
        'v': <RuleViolation>{},
      },
    ];

    for (var i = 0; i < seeds.length; i++) {
      final s = seeds[i];
      final instrument = Instrument.bySymbol(s['sym'] as String);
      final entry = s['entry'] as double;
      final stop = s['stop'] as double;

      // Size each historical trade at the risk rule, so the seeded numbers are
      // internally consistent with the calculator the app ships.
      final sized = sizePosition(
        balance: dailyAllowance,
        riskPercent: maxRiskPercent,
        entryPrice: entry,
        stopPrice: stop,
        instrument: instrument,
      );
      final lots = sized.lots >= Instrument.minLot
          ? sized.lots
          : Instrument.minLot;

      final opened = now.subtract(Duration(days: s['daysAgo'] as int));
      _trades.add(
        Trade(
          id: 'seed-$i',
          symbol: instrument.symbol,
          direction: s['dir'] as TradeDirection,
          lots: lots,
          entryPrice: entry,
          stopPrice: stop,
          targetPrice: s['target'] as double,
          openedAt: opened,
          closedAt: opened.add(const Duration(hours: 5)),
          exitPrice: s['exit'] as double,
          exitReason: (s['exit'] as double) == stop
              ? ExitReason.stopLoss
              : ExitReason.takeProfit,
          balanceAtEntry: dailyAllowance,
          reason: s['reason'] as String,
          lesson: s['lesson'] as String?,
          violations: s['v'] as Set<RuleViolation>,
          isShared: i.isEven,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
