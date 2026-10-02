import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/models/instrument.dart';
import 'package:forex_trading/models/market_mood.dart';

void main() {
  test('the day is Dhaka’s: six hours ahead of UTC', () {
    expect(moodDay(DateTime.utc(2026, 10, 2, 17, 59)), '20261002');
    expect(moodDay(DateTime.utc(2026, 10, 2, 18)), '20261003');
    expect(moodDay(DateTime.utc(2026, 1, 9, 3)), '20260109');
  });

  test('pairs are named as the rules name them', () {
    expect(moodPair(Instrument.eurusd), 'EURUSD');
    expect(moodPair(Instrument.usdjpy), 'USDJPY');
  });

  test('a vote counts once, moves sides, or goes', () {
    var mood = const MarketMood(bulls: {'ana', 'bo'}, bears: {'cy'});
    expect(mood.votes, 3);
    expect(mood.upShare, closeTo(2 / 3, 1e-9));
    expect(mood.sideOf('cy'), MoodSide.down);
    expect(mood.sideOf('me'), isNull);

    mood = mood.withVote('me', MoodSide.down);
    expect(mood.sideOf('me'), MoodSide.down);
    expect(mood.votes, 4);

    mood = mood.withVote('me', MoodSide.up);
    expect((mood.bulls.length, mood.bears.length), (3, 1));

    mood = mood.withVote('me', null);
    expect(mood.votes, 3);
    expect(MarketMood.none.upShare, isNull);
  });
}
