import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/one_time_notice.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/screens/onboarding_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the tour shows once, pages through, and is not shown again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = SessionController(LocalAuthRepository(prefs: prefs))
      ..setLanguage(AppLanguage.en);
    final notice = OneTimeNotice(OnboardingScreen.noticeId, prefs: prefs);

    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => maybeShowTour(context, notice: notice),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Practise at real prices'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Journal every trade'), findsOneWidget);
    await tester.tap(find.text("Let's start"));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(await notice.isDismissed(), isTrue);

    // Not again.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Practise at real prices'), findsNothing);
  });
}
