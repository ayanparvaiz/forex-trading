import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/screens/auth/signup_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walks the whole sign-up flow to its last step and checks that the account
/// cannot be created until the age-and-terms box is ticked.
void main() {
  testWidgets('no account without agreeing to the terms', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthRepository(
      prefs: await SharedPreferences.getInstance(),
    );
    final session = SessionController(auth);
    await tester.runAsync(session.restore);

    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(theme: buildAppTheme(), home: const SignupScreen()),
      ),
    );

    FilledButton next() =>
        tester.widget<FilledButton>(find.byType(FilledButton).last);

    Future<void> advance() async {
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();
    }

    // Language.
    await advance();

    // Identity: the username check is debounced and hits storage, so give it
    // real time to finish.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Test Trader');
    await tester.enterText(fields.at(1), 'fresh_trader');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await tester.pumpAndSettle();
    await advance();

    // Gender: the first choice.
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    await advance();

    // Avatar picked, box not ticked: still no way to finish.
    await tester.tap(find.byKey(const ValueKey('signup-avatar-1')));
    await tester.pump();
    expect(next().onPressed, isNull, reason: 'finished without agreeing');

    // Ticked: now it can.
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(next().onPressed, isNotNull);
  });
}
