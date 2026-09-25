import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/community_repository.dart';
import 'package:forex_trading/data/mock_community.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/profile_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opening someone's profile loads it the first time — not "Could not load"
/// until Retry, which is what happened when the load read the session from
/// initState.
void main() {
  testWidgets("someone's profile loads on the first try", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = LocalAuthRepository(prefs: prefs);
    await tester.runAsync(
      () => auth.signUp(
        username: 'ayan',
        password: 'secret123',
        displayName: 'Ayan',
        gender: Gender.male,
        language: AppLanguage.en,
        avatarId: 1,
      ),
    );
    final session = SessionController(auth);
    await tester.runAsync(session.restore);

    final someone = MockCommunity.traders(AppLanguage.en).first;
    final repository = LocalCommunityRepository(
      language: AppLanguage.en,
      prefs: prefs,
    );

    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: ProfileScreen(username: someone.id, repository: repository),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Could not load.'), findsNothing);
    expect(find.text(someone.name), findsOneWidget);
  });
}
