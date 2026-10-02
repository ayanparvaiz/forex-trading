import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/models/challenge.dart';

void main() {
  test("a week's standing: this week's numbers, or last week's", () {
    final profile = {
      'weekBoard': '2026-W41',
      'weekScore': 92.5,
      'weekTrades': 4,
      'lastWeekBoard': '2026-W40',
      'lastWeekScore': 80,
      'lastWeekTrades': 3,
    };
    final now = WeekStanding.of(profile, '2026-W41');
    expect((now.score, now.trades), (92.5, 4));
    final last = WeekStanding.of(profile, '2026-W40');
    expect((last.score, last.trades), (80.0, 3));
    expect(WeekStanding.of(profile, '2026-W39').score, isNull);
    expect(WeekStanding.of(const {}, '2026-W41').score, isNull);
  });

  test('who is ahead: a score beats none; close is level', () {
    const a = WeekStanding(score: 90, trades: 3);
    const b = WeekStanding(score: 85, trades: 5);
    expect(resultFor(a, b), ChallengeResult.ahead);
    expect(resultFor(b, a), ChallengeResult.behind);
    expect(resultFor(a, WeekStanding.none), ChallengeResult.ahead);
    expect(resultFor(WeekStanding.none, b), ChallengeResult.behind);
    expect(
      resultFor(a, const WeekStanding(score: 90.01)),
      ChallengeResult.level,
    );
    expect(
      resultFor(WeekStanding.none, WeekStanding.none),
      ChallengeResult.open,
    );
  });

  test('the other side, and the id', () {
    const c = Challenge(
      id: 'x',
      fromUid: 'u-a',
      toUid: 'u-b',
      pair: 'ana-bo',
      week: '2026-W40',
      accepted: false,
    );
    expect(c.otherOf('u-a'), 'u-b');
    expect(c.otherOf('u-b'), 'u-a');
    expect(Challenge.idFor('2026-W40', 'ana-bo'), '2026-W40_ana-bo');
    expect(weekOver('2026-W40', DateTime.utc(2026, 10, 2)), isFalse);
    expect(weekOver('2026-W40', DateTime.utc(2026, 10, 5)), isTrue);
  });
}
