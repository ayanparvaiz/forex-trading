import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/market_mood_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/instrument.dart';
import 'package:forex_trading/models/market_mood.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/market_mood_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Moods by `scope_pair_day`, as the rules name them; votes remembered.
class FakeMood implements MarketMoodSource {
  final moods = <String, StreamController<MarketMood>>{};
  final watched = <String>[];
  final votes = <(String, MoodSide?)>[];

  StreamController<MarketMood> of(String id) =>
      moods.putIfAbsent(id, StreamController<MarketMood>.broadcast);

  @override
  Stream<MarketMood> watch(String scope, String pair, String day) {
    watched.add('${scope}_${pair}_$day');
    return of('${scope}_${pair}_$day').stream;
  }

  @override
  Future<void> vote({
    required String scope,
    required String pair,
    required String day,
    required String me,
    required MoodSide? side,
  }) async => votes.add(('${scope}_${pair}_$day', side));
}

void main() {
  final friday = DateTime.utc(2026, 10, 2, 12);

  Future<(FakeMood, SessionController)> pump(
    WidgetTester tester, {
    Instrument instrument = Instrument.eurusd,
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
    final source = FakeMood();
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketMoodCard(
                instrument: instrument,
                source: source,
                now: () => friday,
              ),
            ),
          ),
        ),
      ),
    );
    return (source, session);
  }

  testWidgets("everyone's mood on the pair, today; a tap says mine", (
    tester,
  ) async {
    final (source, session) = await pump(tester);
    expect(source.watched, ['global_EURUSD_20261002']);
    expect(find.textContaining('be the first'), findsOneWidget);

    source
        .of('global_EURUSD_20261002')
        .add(const MarketMood(bulls: {'a', 'b', 'c'}, bears: {'d'}));
    await tester.pump();
    expect(find.text('75% up'), findsOneWidget);
    expect(find.text('25% down'), findsOneWidget);

    await tester.tap(find.text('Down'));
    await tester.pump();
    expect(source.votes, [('global_EURUSD_20261002', MoodSide.down)]);
    // At once: three up, two down.
    expect(find.text('60% up'), findsOneWidget);

    // Again: taken back.
    await tester.tap(find.text('Down'));
    await tester.pump();
    expect(source.votes.last, ('global_EURUSD_20261002', null));
    expect(find.text('75% up'), findsOneWidget);
  });

  testWidgets("in a community: its own mood, or everyone's", (tester) async {
    final (source, session) = await pump(tester);
    session.setCommunity('bulls1');
    await tester.pump();
    expect(source.watched.last, 'bulls1_EURUSD_20261002');
    await tester.tap(find.text('Everyone'));
    await tester.pump();
    expect(source.watched.last, 'global_EURUSD_20261002');
    await tester.tap(find.text('Up'));
    await tester.pump();
    expect(source.votes.single, ('global_EURUSD_20261002', MoodSide.up));
  });

  testWidgets('fits a small phone, in Bangla', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final (source, session) = await pump(tester, language: AppLanguage.bn);
    session.setCommunity('bulls1');
    await tester.pump();
    source
        .of('bulls1_EURUSD_20261002')
        .add(const MarketMood(bulls: {'a'}, bears: {'b', 'c'}));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('33% উপরে'), findsOneWidget);
  });
}
