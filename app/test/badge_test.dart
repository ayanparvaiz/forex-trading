import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/account_store.dart';
import 'package:forex_trading/data/mock_market.dart';
import 'package:forex_trading/models/badge.dart';
import 'package:forex_trading/models/instrument.dart';

void main() {
  group('BadgeRank', () {
    test('starts at Bronze and climbs on thresholds', () {
      expect(BadgeRank.of(0).tier, BadgeTier.bronze);
      expect(BadgeRank.of(24).tier, BadgeTier.bronze);
      expect(BadgeRank.of(25).tier, BadgeTier.silver);
      expect(BadgeRank.of(59).tier, BadgeTier.silver);
      expect(BadgeRank.of(60).tier, BadgeTier.platinum);
      expect(BadgeRank.of(120).tier, BadgeTier.diamond);
      expect(BadgeRank.of(199).tier, BadgeTier.diamond);
      expect(BadgeRank.of(200).tier, BadgeTier.golden);
    });

    test('never drops below zero, however badly someone trades', () {
      final rank = BadgeRank.of(-40);

      expect(rank.points, 0);
      expect(rank.tier, BadgeTier.bronze);
    });

    test('reports how many points the next tier needs', () {
      expect(BadgeRank.of(0).pointsToNext, 25);
      expect(BadgeRank.of(20).pointsToNext, 5);
      expect(BadgeRank.of(59).pointsToNext, 1);
      expect(BadgeRank.of(0).nextTier, BadgeTier.silver);
      expect(BadgeRank.of(120).nextTier, BadgeTier.golden);
    });

    test('Golden keeps counting instead of capping', () {
      expect(BadgeRank.of(200).level, 1);
      expect(BadgeRank.of(249).level, 1);
      expect(BadgeRank.of(250).level, 2);
      expect(BadgeRank.of(500).level, 7);

      // There is always somewhere further to go at the top.
      expect(BadgeRank.of(500).nextTier, isNull);
      expect(BadgeRank.of(500).pointsToNext, greaterThan(0));
    });

    test('shows the level in the Golden label only', () {
      expect(BadgeRank.of(250).label(false), 'Golden 2');
      expect(BadgeRank.of(250).label(true), 'গোল্ডেন 2');
      expect(BadgeRank.of(30).label(false), 'Silver');
    });

    test('progress stays inside 0..1 at every point', () {
      for (var points = 0; points < 600; points += 7) {
        final progress = BadgeRank.of(points).progress;
        expect(progress, inInclusiveRange(0, 1), reason: 'at $points points');
      }
    });

    test('a trader who falls back down loses the tier', () {
      expect(BadgeRank.of(205).tier, BadgeTier.golden);
      // Five losing trades later.
      expect(BadgeRank.of(199).tier, BadgeTier.diamond);
    });
  });

  group('daily allowance', () {
    late AccountStore store;

    setUp(() => store = AccountStore());
    tearDown(() => store.dispose());

    test('balance is the allowance plus only what closed today', () {
      final todaysPnl = store.todaysClosedTrades.fold<double>(
        0,
        (sum, t) => sum + (t.realisedPnl ?? 0),
      );

      expect(
        store.balance,
        closeTo(AccountStore.dailyAllowance + todaysPnl, 0.01),
      );
    });

    test('yesterday does not carry over', () {
      // The seeded history is all from previous days, so none of it may touch
      // today's balance — that is the whole point of the midnight reset.
      final older = store.closedTrades.length - store.todaysClosedTrades.length;

      expect(older, greaterThan(0));
      for (final trade in store.todaysClosedTrades) {
        expect(trade.closedAt!.isBefore(store.dayStart), isFalse);
      }
    });

    test('reset countdown is always within the next 24 hours', () {
      expect(store.untilReset, greaterThan(Duration.zero));
      expect(store.untilReset, lessThanOrEqualTo(const Duration(days: 1)));
    });

    test('badge points are net wins across every day, not just today', () {
      final wins = store.closedTrades
          .where((t) => (t.realisedPnl ?? 0) > 0)
          .length;
      final losses = store.closedTrades.length - wins;

      expect(store.badgePoints, wins - losses);
      expect(store.badge.points, wins - losses < 0 ? 0 : wins - losses);
    });
  });

  group('crowd pressure', () {
    test('net buying lifts the price, net selling drops it', () {
      final buying = MockMarket(seed: 1);
      final selling = MockMarket(seed: 1);

      final start = buying.price(Instrument.eurusd);
      expect(selling.price(Instrument.eurusd), start);

      // Same seed, so the random noise is identical — any difference between
      // the two is the crowd, not luck.
      for (var i = 0; i < 20; i++) {
        buying.applyPressure(Instrument.eurusd, 5);
        selling.applyPressure(Instrument.eurusd, -5);
        buying.tick();
        selling.tick();
      }

      expect(
        buying.price(Instrument.eurusd),
        greaterThan(selling.price(Instrument.eurusd)),
      );
    });

    test('pressure fades instead of pinning the price forever', () {
      final market = MockMarket(seed: 2);
      market.applyPressure(Instrument.eurusd, 100);

      final initial = market.pressureOn(Instrument.eurusd);
      for (var i = 0; i < 50; i++) {
        market.tick();
      }

      expect(
        market.pressureOn(Instrument.eurusd).abs(),
        lessThan(initial * 0.1),
      );
    });

    test('an untouched pair feels no crowd', () {
      final market = MockMarket(seed: 3);
      expect(market.pressureOn(Instrument.gbpusd), 0);
    });
  });
}
