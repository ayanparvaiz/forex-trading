import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/core/mood_stats.dart';
import 'package:forex_trading/models/trade.dart';

void main() {
  Trade trade(String id, TradeMood? mood, double? exit) => Trade(
    id: id,
    symbol: 'EUR/USD',
    direction: TradeDirection.buy,
    lots: 0.1,
    entryPrice: 1.14,
    stopPrice: 1.138,
    targetPrice: 1.144,
    openedAt: DateTime(2026, 10, 1, 9),
    closedAt: exit == null ? null : DateTime(2026, 10, 1, 12),
    exitPrice: exit,
    exitReason: exit == null ? null : ExitReason.manual,
    balanceAtEntry: 10000,
    reason: 'a reason long enough',
    mood: mood,
  );

  test('kept to the storage and back', () {
    final t = trade('t1', TradeMood.fomo, 1.144);
    expect(Trade.fromJson('t1', t.toJson()).mood, TradeMood.fomo);
    expect(Trade.fromJson('t1', trade('t2', null, null).toJson()).mood, isNull);
    expect(t.copyWith(lesson: 'x').mood, TradeMood.fomo);
  });

  test('per mood: trades, wins, average R — open and untagged left out', () {
    final stats = moodStats([
      trade('a', TradeMood.calm, 1.144), // about +2R
      trade('b', TradeMood.calm, 1.138), // about −1R
      trade('c', TradeMood.calm, 1.144),
      trade('d', TradeMood.fomo, 1.138),
      trade('e', TradeMood.fomo, null), // still open
      trade('f', null, 1.144),
    ]);
    expect([for (final s in stats) s.mood], [TradeMood.calm, TradeMood.fomo]);
    final calm = stats.first;
    expect((calm.trades, calm.wins), (3, 2));
    expect(calm.winRate, closeTo(2 / 3, 1e-9));
    expect(calm.averageR, closeTo(1, 0.1));
    expect(stats.last.averageR, lessThan(-1));
  });
}
