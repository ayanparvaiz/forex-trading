import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/account_store.dart';
import 'package:forex_trading/data/trade_repository.dart';
import 'package:forex_trading/models/instrument.dart';
import 'package:forex_trading/models/trade.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The journal is the app's record of what someone actually did, so the thing
/// that has to hold is that it survives: every trade written, every close
/// written, and everything read back exactly as it went in.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Trade sample({
    String id = 't1',
    bool closed = false,
    Set<RuleViolation> violations = const {},
  }) {
    return Trade(
      id: id,
      symbol: 'EUR/USD',
      direction: TradeDirection.sell,
      lots: 0.05,
      entryPrice: 1.08500,
      stopPrice: 1.08700,
      targetPrice: 1.08100,
      openedAt: DateTime(2026, 9, 20, 14, 30),
      closedAt: closed ? DateTime(2026, 9, 20, 16, 5) : null,
      exitPrice: closed ? 1.08100 : null,
      exitReason: closed ? ExitReason.takeProfit : null,
      balanceAtEntry: 10000,
      reason: 'range high rejected twice',
      lesson: closed ? 'waited for the second rejection' : null,
      violations: violations,
      isShared: closed,
    );
  }

  group('serialisation', () {
    test('a trade survives a round trip unchanged', () {
      final before = sample(
        closed: true,
        violations: {RuleViolation.movedStop, RuleViolation.riskTooHigh},
      );
      final after = Trade.fromJson(before.id, before.toJson());

      expect(after.symbol, before.symbol);
      expect(after.direction, before.direction);
      expect(after.lots, before.lots);
      expect(after.entryPrice, before.entryPrice);
      expect(after.stopPrice, before.stopPrice);
      expect(after.targetPrice, before.targetPrice);
      expect(after.openedAt, before.openedAt);
      expect(after.closedAt, before.closedAt);
      expect(after.exitPrice, before.exitPrice);
      expect(after.exitReason, before.exitReason);
      expect(after.balanceAtEntry, before.balanceAtEntry);
      expect(after.reason, before.reason);
      expect(after.lesson, before.lesson);
      expect(after.violations, before.violations);
      expect(after.isShared, before.isShared);

      // And the derived numbers land in the same place, which is the point of
      // storing prices rather than results.
      expect(after.riskPips, closeTo(before.riskPips, 1e-9));
      expect(after.rMultiple, closeTo(before.rMultiple!, 1e-9));
    });

    test('an open trade round trips with nothing invented', () {
      final after = Trade.fromJson('t1', sample().toJson());

      expect(after.isOpen, isTrue);
      expect(after.closedAt, isNull);
      expect(after.exitPrice, isNull);
      expect(after.exitReason, isNull);
      expect(after.lesson, isNull);
    });

    test('an unknown violation name is dropped, not thrown', () {
      // A flag renamed in a later version should cost that one flag, not the
      // whole journal.
      final json = sample().toJson()
        ..['violations'] = ['movedStop', 'somethingFromTheFuture'];

      final after = Trade.fromJson('t1', json);
      expect(after.violations, {RuleViolation.movedStop});
    });
  });

  group('local repository', () {
    test('saves and reads back, oldest first', () async {
      final repo = LocalTradeRepository(uid: 'u1', prefs: prefs);

      await repo.save(sample(id: 'b'));
      await repo.save(
        Trade.fromJson('a', {
          ...sample(id: 'a').toJson(),
          'openedAt': DateTime(2026, 9, 19).toIso8601String(),
        }),
      );

      expect((await repo.load()).map((t) => t.id), ['a', 'b']);
    });

    test('saving the same id replaces rather than duplicates', () async {
      final repo = LocalTradeRepository(uid: 'u1', prefs: prefs);

      await repo.save(sample());
      await repo.save(sample(closed: true));

      final loaded = await repo.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.isOpen, isFalse);
    });

    test('two accounts on one phone do not see each other', () async {
      // Keyed by account for the same reason the Firestore version nests
      // trades under the user document: a journal is nobody else's business.
      await LocalTradeRepository(uid: 'u1', prefs: prefs).save(sample());

      expect(
        await LocalTradeRepository(uid: 'u2', prefs: prefs).load(),
        isEmpty,
      );
    });
  });

  group('store', () {
    test('a new account starts with nothing at all', () async {
      // It used to start with three invented trades, which meant every new
      // trader was shown a win rate, a profit factor and a badge they had not
      // earned. An empty journal is the honest thing to show.
      final store = AccountStore();
      addTearDown(store.dispose);

      expect(store.trades, isEmpty);
      expect(store.stats.total, 0);
      expect(store.badgePoints, 0);
    });

    test('opening and closing a trade both reach storage', () async {
      final repo = LocalTradeRepository(uid: 'u1', prefs: prefs);
      final store = AccountStore(trades: repo);
      addTearDown(store.dispose);

      final trade = store.openTrade(
        instrument: Instrument.eurusd,
        direction: TradeDirection.buy,
        lots: 0.05,
        stopPrice: Instrument.eurusd.shiftByPips(1.085, -20),
        targetPrice: Instrument.eurusd.shiftByPips(1.085, 40),
        reason: 'a reason long enough to pass',
      );

      // The write is deliberately not awaited by the caller, so give the
      // microtask that performs it a turn.
      await Future<void>.delayed(Duration.zero);
      expect((await repo.load()).single.isOpen, isTrue);

      store.closeTrade(trade.id, lesson: 'closed it early on purpose');
      await Future<void>.delayed(Duration.zero);

      final stored = (await repo.load()).single;
      expect(stored.isOpen, isFalse);
      expect(stored.lesson, 'closed it early on purpose');
    });

    test('attaching reads an account journal back', () async {
      final repo = LocalTradeRepository(uid: 'u1', prefs: prefs);
      await repo.save(sample(closed: true));

      final store = AccountStore();
      addTearDown(store.dispose);
      expect(store.trades, isEmpty);

      await store.attach(repo);

      expect(store.trades, hasLength(1));
      expect(store.isLoading, isFalse);
      // Derived on read from the trade that was stored — never stored beside
      // it, so the two can never disagree.
      expect(store.stats.total, 1);
      expect(store.badgePoints, 1);
    });

    test('signing out forgets the journal', () async {
      final repo = LocalTradeRepository(uid: 'u1', prefs: prefs);
      await repo.save(sample(closed: true));

      final store = AccountStore();
      addTearDown(store.dispose);
      await store.attach(repo);

      store.detach();
      expect(store.trades, isEmpty);
    });
  });
}
