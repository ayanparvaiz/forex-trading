import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/account_scope.dart';
import 'package:forex_trading/data/account_store.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/community_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the leaderboard goes to this week and back, again and again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = LocalAuthRepository(prefs: prefs);
    await auth.signUp(
      username: 'tester',
      password: 'secret123',
      displayName: 'Tester',
      gender: Gender.male,
      language: AppLanguage.en,
      avatarId: 1,
    );
    final session = SessionController(auth);
    await session.restore();
    final store = AccountStore();

    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: AccountScope(
          store: store,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const CommunityScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // The second All time is the one that broke: a board, once left, was
    // listened to again.
    for (final chip in ['This week', 'All time', 'This week', 'All time']) {
      await tester.tap(find.text(chip));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'after $chip');
    }

    // The market ticks every second; stop it before the test ends.
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
