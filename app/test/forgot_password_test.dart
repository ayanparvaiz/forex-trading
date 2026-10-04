import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/password_help.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/screens/auth/login_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeHelp implements PasswordHelp {
  FakeHelp({this.works = true});
  bool works;
  final asked = <(String, String, String)>[];

  @override
  Future<bool> ask({
    required String username,
    required String contact,
    String note = '',
  }) async {
    asked.add((username, contact, note));
    return works;
  }
}

void main() {
  Future<void> pump(WidgetTester tester, PasswordHelp help) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    );
    await session.restore();
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: LoginScreen(help: help),
        ),
      ),
    );
  }

  testWidgets('locked out: ask the admins, with the username already in', (
    tester,
  ) async {
    final help = FakeHelp(works: false);
    await pump(tester, help);
    await tester.enterText(find.byType(TextField).first, '@Rifat');
    await tester.pump();
    await tester.tap(find.text('Forgot your password?'));
    await tester.pumpAndSettle();

    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      '@Rifat',
      reason: 'what was typed on the sign-in screen',
    );
    await tester.enterText(fields.at(1), '01700-000000');
    await tester.enterText(fields.at(2), 'New phone');
    await tester.pump();
    final send = find.widgetWithText(FilledButton, 'Send to the admins');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(help.asked.single, ('rifat', '01700-000000', 'New phone'));
    expect(find.textContaining('Could not send'), findsOneWidget);

    // Back online: sent, and told what happens next.
    help.works = true;
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('will reach you at 01700-000000'),
      findsOneWidget,
    );
  });
}
