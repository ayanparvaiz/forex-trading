import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalAuthRepository auth;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    auth = LocalAuthRepository(prefs: prefs);
  });

  Future<AuthResult> signUp({
    String username = 'rifat',
    String password = 'secret123',
    String name = 'Rifat Hasan',
  }) {
    return auth.signUp(
      username: username,
      password: password,
      displayName: name,
      gender: Gender.male,
      language: AppLanguage.bn,
      avatarId: 1,
    );
  }

  group('sign up', () {
    test('creates the account and signs the user straight in', () async {
      final result = await signUp();

      expect(result, isA<AuthSuccess>());
      final profile = (result as AuthSuccess).profile;
      expect(profile.username, 'rifat');
      expect(profile.displayName, 'Rifat Hasan');
      expect(profile.language, AppLanguage.bn);

      expect((await auth.currentUser())?.username, 'rifat');
    });

    test('refuses a username that is already taken', () async {
      await signUp();
      final second = await signUp(name: 'Someone Else');

      expect(second, isA<AuthFailure>());
      expect((second as AuthFailure).error, AuthError.usernameTaken);
    });

    test('treats usernames case-insensitively', () async {
      await signUp(username: 'rifat');

      expect(await auth.isUsernameAvailable('RIFAT'), isFalse);
      final clash = await signUp(username: '  Rifat  ');
      expect((clash as AuthFailure).error, AuthError.usernameTaken);
    });

    test('rejects bad usernames, short passwords and empty names', () async {
      expect(
        ((await signUp(username: 'ab')) as AuthFailure).error,
        AuthError.invalidUsername,
      );
      expect(
        ((await signUp(username: 'Rifat Hasan')) as AuthFailure).error,
        AuthError.invalidUsername,
      );
      expect(
        ((await signUp(password: '123')) as AuthFailure).error,
        AuthError.weakPassword,
      );
      expect(
        ((await signUp(name: '   ')) as AuthFailure).error,
        AuthError.nameRequired,
      );
    });

    test('never writes the password anywhere', () async {
      await signUp(password: 'hunter2hunter2');

      final dump = prefs.getString('auth.accounts')!;
      expect(dump, isNot(contains('hunter2hunter2')));
      expect(dump, contains('salt'));
      expect(dump, contains('hash'));
    });

    test('salts each account separately, so equal passwords differ', () async {
      await signUp(username: 'rifat', password: 'samepassword');
      await auth.logOut();
      await signUp(username: 'nusrat', password: 'samepassword');

      final dump = prefs.getString('auth.accounts')!;
      final hashes = RegExp(
        r'"hash":"([^"]+)"',
      ).allMatches(dump).map((m) => m.group(1)).toList();

      expect(hashes, hasLength(2));
      expect(hashes[0], isNot(hashes[1]));
    });
  });

  group('log in', () {
    test('accepts the right password', () async {
      await signUp();
      await auth.logOut();
      expect(await auth.currentUser(), isNull);

      final result = await auth.logIn(username: 'rifat', password: 'secret123');
      expect(result, isA<AuthSuccess>());
      expect((await auth.currentUser())?.displayName, 'Rifat Hasan');
    });

    test('rejects the wrong password', () async {
      await signUp();
      final result = await auth.logIn(username: 'rifat', password: 'wrong123');

      expect((result as AuthFailure).error, AuthError.wrongCredentials);
    });

    test(
      'gives the same error for an unknown user, to avoid leaking who exists',
      () async {
        await signUp();

        final unknown = await auth.logIn(
          username: 'nobody',
          password: 'secret123',
        );
        final wrongPassword = await auth.logIn(
          username: 'rifat',
          password: 'nope12345',
        );

        expect(
          (unknown as AuthFailure).error,
          (wrongPassword as AuthFailure).error,
        );
      },
    );
  });

  group('change password', () {
    test('the right current password changes it', () async {
      await signUp(password: 'secret123');

      final result = await auth.changePassword(
        current: 'secret123',
        next: 'newsecret9',
      );
      expect(result, isA<AuthSuccess>());

      await auth.logOut();
      expect(
        await auth.logIn(username: 'rifat', password: 'newsecret9'),
        isA<AuthSuccess>(),
      );
    });

    test('the old password stops working', () async {
      await signUp(password: 'secret123');
      await auth.changePassword(current: 'secret123', next: 'newsecret9');
      await auth.logOut();

      final old = await auth.logIn(username: 'rifat', password: 'secret123');
      expect((old as AuthFailure).error, AuthError.wrongCredentials);
    });

    test('a wrong current password changes nothing', () async {
      // Without this check, anyone holding an unlocked phone could lock its
      // owner out — and there is no password reset to get back in with.
      await signUp(password: 'secret123');

      final result = await auth.changePassword(
        current: 'guess1234',
        next: 'newsecret9',
      );
      expect((result as AuthFailure).error, AuthError.wrongCredentials);

      await auth.logOut();
      expect(
        await auth.logIn(username: 'rifat', password: 'secret123'),
        isA<AuthSuccess>(),
      );
    });

    test('a new password must meet the same minimum as sign-up', () async {
      await signUp(password: 'secret123');

      final result = await auth.changePassword(
        current: 'secret123',
        next: 'abc',
      );
      expect((result as AuthFailure).error, AuthError.weakPassword);
    });
  });

  group('usernames', () {
    test('reports availability, and rejects invalid shapes outright', () async {
      expect(await auth.isUsernameAvailable('freename'), isTrue);
      await signUp(username: 'freename');
      expect(await auth.isUsernameAvailable('freename'), isFalse);

      expect(await auth.isUsernameAvailable('no'), isFalse);
      expect(await auth.isUsernameAvailable('Has Space'), isFalse);
    });

    test('suggests only names that are actually free', () async {
      await signUp(username: 'rifatfx');

      final suggestions = await auth.suggestUsernames('rifat');

      expect(suggestions, isNotEmpty);
      expect(suggestions, isNot(contains('rifatfx')));
      for (final s in suggestions) {
        expect(
          AuthRepository.usernamePattern.hasMatch(s),
          isTrue,
          reason: '$s should be a valid username',
        );
        expect(await auth.isUsernameAvailable(s), isTrue);
      }
    });

    test('builds a usable stem out of an unusable name', () async {
      final suggestions = await auth.suggestUsernames('Rifat Hasan!!');

      expect(suggestions, isNotEmpty);
      for (final s in suggestions) {
        expect(AuthRepository.usernamePattern.hasMatch(s), isTrue);
      }
    });
  });

  test('profile edits persist, username does not change', () async {
    final profile = ((await signUp()) as AuthSuccess).profile;

    await auth.updateProfile(
      profile.copyWith(displayName: 'Rifat H.', avatarId: 2),
    );

    final reloaded = await auth.currentUser();
    expect(reloaded!.displayName, 'Rifat H.');
    expect(reloaded.avatarId, 2);
    expect(reloaded.username, 'rifat');
  });

  test('cohort is the month the account was made', () {
    expect(
      UserProfile.cohortFor(DateTime(2026, 9, 23), AppLanguage.bn),
      'সেপ্টেম্বর ব্যাচ',
    );
    expect(
      UserProfile.cohortFor(DateTime(2026, 9, 23), AppLanguage.en),
      'September batch',
    );
  });
}
