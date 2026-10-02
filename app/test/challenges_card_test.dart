import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/challenges_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/challenge.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/challenges_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Challenges and sides in memory.
class FakeChallenges extends ChallengesRepository {
  final mine = StreamController<List<Challenge>>.broadcast();
  final sides = <String, (String, WeekStanding)>{};
  final accepted = <String>[];
  final removed = <String>[];

  @override
  Stream<List<Challenge>> watchMine(String uid, DateTime now) => mine.stream;

  @override
  Stream<(String, WeekStanding)> watchSide(String uid, String week) =>
      Stream.value(sides[uid] ?? ('', WeekStanding.none));

  @override
  Future<void> accept(String id) async => accepted.add(id);

  @override
  Future<void> remove(String id) async => removed.add(id);
}

void main() {
  late String me;

  Future<FakeChallenges> pump(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthRepository(
      prefs: await SharedPreferences.getInstance(),
    );
    await auth.signUp(
      username: 'tester',
      password: 'secret123',
      displayName: 'Tester',
      gender: Gender.male,
      language: language,
      avatarId: 1,
    );
    final session = SessionController(auth);
    await session.restore();
    me = session.uid!;
    final repo = FakeChallenges();
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChallengesCard(
                repository: repo,
                // Friday of week 40.
                now: () => DateTime.utc(2026, 10, 2, 12),
              ),
            ),
          ),
        ),
      ),
    );
    return repo;
  }

  Challenge challenge({
    required String from,
    required String to,
    bool accepted = true,
    String week = '2026-W40',
    String pair = 'x',
  }) => Challenge(
    id: '${week}_$pair',
    fromUid: from,
    toUid: to,
    pair: pair,
    week: week,
    accepted: accepted,
  );

  testWidgets('nothing when there are none', (tester) async {
    final repo = await pump(tester);
    repo.mine.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('Weekly challenges'), findsNothing);
  });

  testWidgets('an invitation: accept or decline', (tester) async {
    final repo = await pump(tester);
    repo.sides['u-ana'] = ('Ana', WeekStanding.none);
    repo.mine.add([challenge(from: 'u-ana', to: me, accepted: false)]);
    await tester.pumpAndSettle();
    expect(find.text('Ana challenged you'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    expect(repo.accepted, ['2026-W40_x']);
    await tester.tap(find.text('Decline'));
    expect(repo.removed, ['2026-W40_x']);
  });

  testWidgets("on: both scores, and who's ahead; last week, who won", (
    tester,
  ) async {
    final repo = await pump(tester);
    repo.sides[me] = ('Tester', const WeekStanding(score: 92, trades: 4));
    repo.sides['u-ana'] = ('Ana', const WeekStanding(score: 81, trades: 3));
    repo.mine.add([
      challenge(from: me, to: 'u-ana'),
      Challenge(
        id: 'old',
        fromUid: 'u-ana',
        toUid: me,
        pair: 'x',
        week: '2026-W39',
        accepted: true,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('vs Ana'), findsOneWidget);
    expect(find.text("You're ahead"), findsOneWidget);
    expect(find.text('You 92 · Ana 81'), findsNWidgets(2));
    expect(find.text('Last week · vs Ana'), findsOneWidget);
    expect(find.text('You won 🏆'), findsOneWidget);
  });

  testWidgets('fits a small phone, in Bangla', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = await pump(tester, language: AppLanguage.bn);
    repo.sides['u-ana'] = ('Anika Tabassum Chowdhury', WeekStanding.none);
    repo.mine.add([
      challenge(from: me, to: 'u-ana'),
      challenge(from: 'u-bo', to: me, accepted: false, pair: 'y'),
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
