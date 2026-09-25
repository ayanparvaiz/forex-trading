import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/mock_community.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/profile_screen.dart';
import 'package:forex_trading/screens/search_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Search on the on-device community: suggestions, typing, opening someone,
/// and remembering them.
void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('suggests, finds, opens, remembers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthRepository(
      prefs: await SharedPreferences.getInstance(),
    );
    await tester.runAsync(
      () => auth.signUp(
        username: 'searcher',
        password: 'secret123',
        displayName: 'Searcher',
        gender: Gender.male,
        language: AppLanguage.en,
        avatarId: 1,
      ),
    );
    final session = SessionController(auth);
    await tester.runAsync(session.restore);

    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(theme: buildAppTheme(), home: const SearchScreen()),
      ),
    );
    await settle(tester);

    // Nothing typed: the board is suggested.
    final someone = MockCommunity.traders(AppLanguage.en).first;
    expect(find.text('Suggested for you'), findsOneWidget);
    expect(find.text(someone.name), findsWidgets);

    // Typed: found by the start of their username.
    await tester.enterText(find.byType(TextField), '@${someone.id}');
    await settle(tester);
    expect(find.text('People'), findsOneWidget);
    expect(find.text(someone.name), findsWidgets);

    // Nobody matches this.
    await tester.enterText(find.byType(TextField), 'zzzz-nobody');
    await settle(tester);
    expect(find.text('No one found for "zzzz-nobody"'), findsOneWidget);

    // Opened, then back: remembered at the top.
    await tester.enterText(find.byType(TextField), someone.id);
    await settle(tester);
    await tester.tap(find.text(someone.name).first);
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.enterText(find.byType(TextField), '');
    await settle(tester);
    expect(find.text('Recent'), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await settle(tester);
    expect(find.text('Recent'), findsNothing);
  });
}
