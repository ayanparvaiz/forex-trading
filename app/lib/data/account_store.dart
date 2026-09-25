import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/calculations.dart';
import '../core/leaderboard_stats.dart';
import '../models/badge.dart';
import '../models/instrument.dart';
import '../models/trade.dart';
import 'mock_market.dart';
import 'reference_rates.dart';
import 'score_sync.dart';
import 'trade_repository.dart';

/// Everything about the learner's demo account: points, positions, history.
///
/// The account is a daily contest. Everyone is handed the same 10,000 points at
/// midnight and everyone starts level, so nobody can buy an advantage by
/// grinding yesterday — the only thing that carries over is the badge ladder.
///
/// The trades are real and they are stored. Everything else on this screen —
/// every statistic, the discipline score, the badge, the drawdown — is derived
/// from them on read, never stored beside them, so no number here can ever
/// disagree with the trades that produced it.
///
/// The prices, on the other hand, are practice prices: [MockMarket] moves them
/// on the device, from the day's real reference rates. This is a practice
/// account, and that part is the point.
class AccountStore extends ChangeNotifier {
  AccountStore({MockMarket? market, TradeRepository? trades})
    : market = market ?? MockMarket(),
      _repository = trades ?? const NoTradeRepository() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      this.market.tick();
      _settleHitOrders();
      notifyListeners();
    });
  }

  final MockMarket market;
  Timer? _ticker;

  /// The day's reference rates: each pair heads for its rate — at once when
  /// nothing is open on it, gradually when something is, so no open
  /// position's result leaps because a number arrived.
  void applyReferenceRates(ReferenceRates rates) {
    for (final instrument in Instrument.all) {
      final price = rates.pairs[instrument.symbol];
      if (price == null) continue;
      final open = openTrades.any(
        (t) => t.instrument.symbol == instrument.symbol,
      );
      market.setAnchor(instrument, price, jump: !open);
    }
    market.anchorDate = rates.date;
    notifyListeners();
  }

  TradeRepository _repository;
  ScoreSync _scores = const NoScoreSync();

  /// True until the stored journal has been read.
  ///
  /// Screens use it to tell "no trades yet" apart from "not loaded yet" — the
  /// two look identical and mean opposite things, and showing a new trader an
  /// empty journal that is really a loading journal is how a working app looks
  /// broken.
  bool _loading = false;
  bool get isLoading => _loading;

  /// Points the store at an account and reads its journal.
  ///
  /// Called when a session is restored or somebody signs in. Signing in as
  /// somebody else replaces the trades rather than merging them, which is the
  /// only safe answer on a shared phone.
  Future<void> attach(
    TradeRepository repository, {
    ScoreSync scores = const NoScoreSync(),
  }) async {
    _repository = repository;
    _scores.dispose();
    _scores = scores;
    _trades.clear();
    _loading = true;
    notifyListeners();

    try {
      _trades.addAll(await repository.load());
    } catch (error) {
      // The journal stays empty and the app stays usable. Reporting it is the
      // screens' job — silently pretending the account has no history would be
      // worse than showing nothing.
      debugPrint('journal could not be loaded: $error');
    }

    _loading = false;
    notifyListeners();
  }

  /// Forgets the signed-in account's trades. Called on log out.
  void detach() {
    _repository = const NoTradeRepository();
    _scores.dispose();
    _scores = const NoScoreSync();
    _trades.clear();
    _loading = false;
    notifyListeners();
  }

  /// Writes a trade without making the caller wait for the network.
  ///
  /// The in-memory list is what the screens draw, and it is already correct by
  /// the time this runs. Awaiting the write would mean a spinner between
  /// tapping Buy and seeing the position, for a round trip that changes
  /// nothing on screen.
  ///
  /// [movesScore] asks the stats worker to recompute afterwards — but only
  /// once the write has landed. The worker reads the trades from Firestore, so
  /// asking before the save finishes would compute the score from the journal
  /// as it was one trade ago.
  void _persist(Trade trade, {bool movesScore = false}) {
    unawaited(
      _repository
          .save(trade)
          .then((_) {
            if (movesScore) _scores.request();
          })
          .catchError((Object error) {
            debugPrint('trade ${trade.id} was not saved: $error');
          }),
    );
  }

  /// This account's leaderboard numbers, computed here from the same trades
  /// and the same formula the worker uses — so the row the trader sees for
  /// themselves is right immediately, before the worker has written it.
  LeaderboardStats get leaderboardStats =>
      LeaderboardStats.from(_trades, now: DateTime.now());

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
    _persist(recorded);

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
    _persist(_trades[index], movesScore: true);

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
    _persist(_trades[index]);
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
    _persist(_trades[index], movesScore: true);
    notifyListeners();
  }

  void shareTrade(String id) {
    final index = _trades.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _trades[index] = _trades[index].copyWith(isShared: true);
    _persist(_trades[index]);
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
        // Written the moment it fills. This runs off a one-second timer with
        // nobody necessarily looking at the app, and a stop that filled but
        // was never stored would reopen as a live position next launch.
        _persist(_trades[i], movesScore: true);
      } else if (targetHit) {
        _trades[i] = _closeWith(
          trade,
          exit: trade.targetPrice,
          reason: ExitReason.takeProfit,
        );
        _persist(_trades[i], movesScore: true);
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
