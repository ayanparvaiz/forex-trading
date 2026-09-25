import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/delete_account_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The delete screen end to end, on on-device accounts: a wrong password
/// deletes nothing, the right one deletes the account and signs out.
void main() {
  testWidgets('deletes only with the right password, then signs out', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthRepository(
      prefs: await SharedPreferences.getInstance(),
    );
    await tester.runAsync(
      () => auth.signUp(
        username: 'rifat',
        password: 'secret123',
        displayName: 'Rifat',
        gender: Gender.male,
        language: AppLanguage.en,
        avatarId: 1,
      ),
    );
    final session = SessionController(auth);
    await tester.runAsync(session.restore);
    expect(session.isSignedIn, isTrue);

    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          // Stands in for the app's root, which is the login screen once
          // nobody is signed in.
          home: Builder(
            builder: (context) => Scaffold(
              body: context.session.isSignedIn
                  ? TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DeleteAccountScreen(),
                        ),
                      ),
                      child: const Text('open'),
                    )
                  : const Text('signed out'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Delete my account');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    Future<void> deleteWith(String password) async {
      await tester.enterText(find.byType(TextField), password);
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.text(
          '@rifat and everything in it will be deleted. '
          'There is no undo.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete account'),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }

    await deleteWith('guess1234');
    expect(find.text('Wrong password'), findsOneWidget);
    expect(session.isSignedIn, isTrue);
    expect(await tester.runAsync(auth.currentUser), isNotNull);

    await deleteWith('secret123');
    expect(session.isSignedIn, isFalse);
    expect(find.text('signed out'), findsOneWidget);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
    final login = await tester.runAsync(
      () => auth.logIn(username: 'rifat', password: 'secret123'),
    );
    expect(login, isA<AuthFailure>());
  });
}
