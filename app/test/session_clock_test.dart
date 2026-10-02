import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/session_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    DateTime at, {
    AppLanguage language = AppLanguage.en,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    )..setLanguage(language);
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: SessionClock(now: () => at)),
        ),
      ),
    );
  }

  testWidgets('what is open, for how long, and the busiest hours', (
    tester,
  ) async {
    // A Friday, 18:40 in Dhaka.
    await pump(tester, DateTime.utc(2026, 10, 2, 12, 40));
    expect(find.text('Closes in 3h 20m'), findsOneWidget); // London
    expect(find.text('Closes in 8h 20m'), findsOneWidget); // New York
    expect(find.text('Opens in 2d 11h'), findsOneWidget); // Tokyo, Monday
    expect(find.textContaining('busiest hours'), findsOneWidget);
  });

  testWidgets('the weekend says so', (tester) async {
    await pump(tester, DateTime.utc(2026, 10, 3, 12));
    expect(find.textContaining('Weekend'), findsOneWidget);
    expect(find.textContaining('Closes in'), findsNothing);
  });

  testWidgets('fits a small phone, in Bangla', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      DateTime.utc(2026, 10, 2, 12, 40),
      language: AppLanguage.bn,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('লন্ডন'), findsOneWidget);
  });
}
