import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/strings.dart';
import '../models/user_profile.dart';
import 'trade_repository.dart';
import 'username_suggestions.dart';

/// Why a sign-up or log-in did not go through.
enum AuthError {
  wrongCredentials,
  usernameTaken,
  invalidUsername,
  weakPassword,
  nameRequired,

  /// Firebase refuses further attempts for a while after several wrong
  /// passwords in a row.
  tooManyAttempts,
  unknown,
}

/// Outcome of an auth call.
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess(this.profile);
  final UserProfile profile;
}

class AuthFailure extends AuthResult {
  const AuthFailure(this.error);
  final AuthError error;
}

/// Account storage and sign-in.
///
/// Deliberately username-and-password only: no email, no phone, no recovery.
/// Nothing here can be reset, because nothing here can identify a person — and
/// on a demo account with no real money, a forgotten password costs a signup,
/// not a savings account.
abstract class AuthRepository {
  Future<UserProfile?> currentUser();

  /// The signed-in account's id, or null.
  ///
  /// Distinct from the username: rules and notifications key off this, and on
  /// Firebase it is the auth uid rather than anything the person chose.
  Future<String?> currentUid();

  Future<bool> isUsernameAvailable(String username);

  /// Free usernames near [base], for when the one they wanted is taken.
  Future<List<String>> suggestUsernames(String base, {int count = 4});

  /// Creates an account.
  ///
  /// [startSession] signs the new account in, which is what a person
  /// completing sign-up wants. Seeding passes false: creating twenty demo
  /// accounts must not throw whoever is already signed in out of the app.
  Future<AuthResult> signUp({
    required String username,
    required String password,
    required String displayName,
    required Gender gender,
    required AppLanguage language,
    required int avatarId,
    bool startSession = true,

    /// The version of the terms and privacy policy the person agreed to,
    /// recorded on the new account. Null only for accounts created by the
    /// seeding tools, which no person signed up for.
    String? termsVersion,
  });

  Future<AuthResult> logIn({
    required String username,
    required String password,
  });

  Future<void> logOut();

  Future<void> updateProfile(UserProfile profile);

  /// Replaces the signed-in account's password, after checking the current
  /// one. Asking for the current password is not a formality: without it,
  /// anyone who picked up an unlocked phone could lock its owner out, and
  /// with no password reset in this app there would be no way back in.
  Future<AuthResult> changePassword({
    required String current,
    required String next,
  });

  /// Deletes the signed-in account for good, after checking its password.
  /// Returns null once it is gone and nobody is signed in.
  ///
  /// The password again, even though the person is signed in: this cannot be
  /// undone, and a phone left unlocked should not be enough to do it.
  Future<AuthError?> deleteAccount({required String password});

  /// Lowercase letters, digits and underscore, 3–20 characters.
  static final usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

  static const minPasswordLength = 6;

  /// Trims and lowercases, so `  Rifat ` and `rifat` are the same account.
  static String normalise(String username) => username.trim().toLowerCase();

  static AuthError? validate({
    required String username,
    required String password,
    required String displayName,
  }) {
    if (!usernamePattern.hasMatch(normalise(username))) {
      return AuthError.invalidUsername;
    }
    if (password.length < minPasswordLength) return AuthError.weakPassword;
    if (displayName.trim().isEmpty) return AuthError.nameRequired;
    return null;
  }
}

/// On-device accounts, backed by shared preferences.
///
/// Real enough to use: passwords are salted and stretched rather than stored,
/// so a rooted device or a preferences dump does not hand over the password.
/// The Firestore-backed implementation will keep this same interface.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({SharedPreferences? prefs}) : _injected = prefs;

  final SharedPreferences? _injected;
  SharedPreferences? _cached;

  static const _accountsKey = 'auth.accounts';
  static const _sessionKey = 'auth.session';

  /// PBKDF2 rounds. High enough to make guessing slow, low enough to keep the
  /// sign-up button responsive on a budget Android phone.
  static const _iterations = 10000;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  Future<Map<String, dynamic>> _accounts() async {
    final raw = (await _prefs).getString(_accountsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Corrupt storage should lock nobody out of making a fresh account.
      return {};
    }
  }

  Future<void> _saveAccounts(Map<String, dynamic> accounts) async {
    await (await _prefs).setString(_accountsKey, jsonEncode(accounts));
  }

  @override
  Future<UserProfile?> currentUser() async {
    final username = (await _prefs).getString(_sessionKey);
    if (username == null) return null;

    final account = (await _accounts())[username] as Map<String, dynamic>?;
    if (account == null) return null;

    return UserProfile.fromJson(
      (account['profile'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<String?> currentUid() async => (await _prefs).getString(_sessionKey);

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final normalised = AuthRepository.normalise(username);
    if (!AuthRepository.usernamePattern.hasMatch(normalised)) return false;
    return !(await _accounts()).containsKey(normalised);
  }

  @override
  Future<List<String>> suggestUsernames(String base, {int count = 4}) =>
      suggestFreeUsernames(base, isFree: isUsernameAvailable, count: count);

  @override
  Future<AuthResult> signUp({
    required String username,
    required String password,
    required String displayName,
    required Gender gender,
    required AppLanguage language,
    required int avatarId,
    bool startSession = true,
    String? termsVersion,
  }) async {
    final invalid = AuthRepository.validate(
      username: username,
      password: password,
      displayName: displayName,
    );
    if (invalid != null) return AuthFailure(invalid);

    final normalised = AuthRepository.normalise(username);
    final accounts = await _accounts();
    if (accounts.containsKey(normalised)) {
      return const AuthFailure(AuthError.usernameTaken);
    }

    final now = DateTime.now();
    final profile = UserProfile(
      username: normalised,
      displayName: displayName.trim(),
      gender: gender,
      language: language,
      avatarId: avatarId,
      createdAt: now,
      cohort: UserProfile.cohortFor(now, language),
    );

    final salt = _newSalt();
    accounts[normalised] = {
      'salt': base64Encode(salt),
      'hash': base64Encode(_derive(password, salt)),
      'profile': profile.toJson(),
    };

    await _saveAccounts(accounts);
    if (startSession) {
      await (await _prefs).setString(_sessionKey, normalised);
    }
    return AuthSuccess(profile);
  }

  @override
  Future<AuthResult> logIn({
    required String username,
    required String password,
  }) async {
    final normalised = AuthRepository.normalise(username);
    final account = (await _accounts())[normalised] as Map<String, dynamic>?;

    // One error for both a missing account and a bad password, so the screen
    // cannot be used to find out which usernames exist.
    if (account == null) {
      return const AuthFailure(AuthError.wrongCredentials);
    }

    final salt = base64Decode(account['salt'] as String);
    final expected = account['hash'] as String;
    if (base64Encode(_derive(password, salt)) != expected) {
      return const AuthFailure(AuthError.wrongCredentials);
    }

    await (await _prefs).setString(_sessionKey, normalised);
    return AuthSuccess(
      UserProfile.fromJson((account['profile'] as Map).cast<String, dynamic>()),
    );
  }

  @override
  Future<void> logOut() async => (await _prefs).remove(_sessionKey);

  @override
  Future<AuthResult> changePassword({
    required String current,
    required String next,
  }) async {
    final username = (await _prefs).getString(_sessionKey);
    final accounts = await _accounts();
    final account = accounts[username] as Map<String, dynamic>?;
    if (account == null) return const AuthFailure(AuthError.unknown);

    final salt = base64Decode(account['salt'] as String);
    if (base64Encode(_derive(current, salt)) != account['hash']) {
      return const AuthFailure(AuthError.wrongCredentials);
    }
    if (next.length < AuthRepository.minPasswordLength) {
      return const AuthFailure(AuthError.weakPassword);
    }

    // A new salt with the new password, not the old one reused: a salt
    // belongs to one password, and reusing it would tie the two together.
    final fresh = _newSalt();
    account['salt'] = base64Encode(fresh);
    account['hash'] = base64Encode(_derive(next, fresh));
    await _saveAccounts(accounts);
    return AuthSuccess(
      UserProfile.fromJson((account['profile'] as Map).cast<String, dynamic>()),
    );
  }

  @override
  Future<AuthError?> deleteAccount({required String password}) async {
    final prefs = await _prefs;
    final username = prefs.getString(_sessionKey);
    final accounts = await _accounts();
    final account = accounts[username] as Map<String, dynamic>?;
    if (username == null || account == null) return AuthError.unknown;

    final salt = base64Decode(account['salt'] as String);
    if (base64Encode(_derive(password, salt)) != account['hash']) {
      return AuthError.wrongCredentials;
    }

    accounts.remove(username);
    await _saveAccounts(accounts);
    // On this device the account id is the username.
    await prefs.remove(LocalTradeRepository.keyFor(username));
    await prefs.remove(_sessionKey);
    return null;
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    final accounts = await _accounts();
    final account = accounts[profile.username] as Map<String, dynamic>?;
    if (account == null) return;
    account['profile'] = profile.toJson();
    await _saveAccounts(accounts);
  }

  List<int> _newSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }

  /// PBKDF2-HMAC-SHA256, one block wide because the output is exactly one
  /// SHA-256 digest.
  List<int> _derive(String password, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(password));

    // U1 = HMAC(password, salt || INT_32_BE(1))
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.of(u);

    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }
}
