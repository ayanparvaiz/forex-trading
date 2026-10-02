import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/community.dart';
import 'package:forex_trading/screens/communities_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('month ids read as months; anything else does not', () {
    expect(monthOf('2026-09'), DateTime(2026, 9));
    expect(monthOf('2026-13'), isNull);
    expect(monthOf('Sept'), isNull);
  });

  test('the month crowned last is the one before, in Dhaka', () {
    expect(lastMonthId(DateTime.utc(2026, 10, 2, 12)), '2026-09');
    // 31 October 19:00 UTC is already November in Dhaka.
    expect(lastMonthId(DateTime.utc(2026, 10, 31, 19)), '2026-10');
    expect(lastMonthId(DateTime.utc(2027, 1, 5)), '2026-12');
  });

  const champ = Champion(
    month: '2026-09',
    communityId: 'buetuni',
    name: 'Bangladesh University of Engineering and Technology',
    points: 253,
  );

  Future<void> pump(WidgetTester tester, AppLanguage language) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    )..setLanguage(language);
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: ChampionBanner(champion: champ)),
        ),
      ),
    );
  }

  testWidgets('the banner names the month, the champion, its points', (
    tester,
  ) async {
    await pump(tester, AppLanguage.en);
    expect(
      find.text(
        '🏆 Sep 2026 champion: Bangladesh University of Engineering and '
        'Technology',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('253'), findsOneWidget);
  });

  testWidgets('fits a small phone, in Bangla', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pump(tester, AppLanguage.bn);
    expect(tester.takeException(), isNull);
  });
}
