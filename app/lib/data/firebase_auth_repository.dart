import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../i18n/strings.dart';
import '../models/user_profile.dart';
import 'account_eraser.dart';
import 'auth_repository.dart';
import 'username_suggestions.dart';

/// Accounts backed by Firebase Auth and Firestore.
///
/// Firebase Auth has no concept of a username, so each account is created
/// against a synthetic address — `rifat@users.forex-9f21b.app`. Nothing is ever
/// sent to it and it is never shown; it exists because the API demands an email
/// field. The username itself is the identity, and Firestore enforces that it
/// is unique.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AccountEraser Function()? eraser,
  }) : _auth = auth ?? fb.FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _newEraser = eraser ?? AccountEraser.new;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final AccountEraser Function() _newEraser;

  /// Domain for the synthetic addresses. Not a real mail domain, and never
  /// resolved — using a domain nobody owns would risk it becoming real later.
  static const _domain = 'users.forex-9f21b.app';

  static String _emailFor(String username) => '$username@$_domain';

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// One document per claimed username, keyed by the username itself.
  ///
  /// Uniqueness comes from the document id — Firestore refuses a create on an
  /// id that exists. Checking a query first and then writing would race two
  /// people signing up with the same name at the same moment.
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  @override
  Future<UserProfile?> currentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _users.doc(user.uid).get();
    final data = snapshot.data();
    if (data == null) return null;

    return UserProfile.fromJson(data);
  }

  @override
  Future<String?> currentUid() async => _auth.currentUser?.uid;

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final normalised = AuthRepository.normalise(username);
    if (!AuthRepository.usernamePattern.hasMatch(normalised)) return false;

    final snapshot = await _usernames.doc(normalised).get();
    return !snapshot.exists;
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

    // Cheap early exit. The real guarantee is the transaction below; this just
    // avoids creating an auth user that is about to be thrown away.
    if (!await isUsernameAvailable(normalised)) {
      return const AuthFailure(AuthError.usernameTaken);
    }

    fb.UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: _emailFor(normalised),
        password: password,
      );

      final uid = credential.user!.uid;
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

      // Claim and profile land together. If the claim loses a race the whole
      // thing aborts, and the auth user created above is deleted below —
      // leaving an orphan would burn the username forever.
      await _db.runTransaction((tx) async {
        final claim = await tx.get(_usernames.doc(normalised));
        if (claim.exists) {
          throw fb.FirebaseAuthException(code: 'username-already-in-use');
        }
        tx.set(_usernames.doc(normalised), {
          'uid': uid,
          'claimedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_users.doc(uid), {
          ...profile.toJson(),
          // What search looks names up by; the rules hold it to the name.
          'nameLower': profile.displayName.toLowerCase(),
          // Server-owned from here on. Written once at creation so the rules
          // can compare against them on every later update.
          'disciplineScore': 100,
          'badgePoints': 0,
          'tradeCount': 0,
          'winRate': 0,
          'journalStreak': 0,
          'totalR': 0,
          'createdAtServer': FieldValue.serverTimestamp(),
          // What this person agreed to, and when. Outside the fields a
          // profile update may touch, so it stays as it was agreed.
          if (termsVersion != null) ...{
            'termsVersion': termsVersion,
            'termsAcceptedAt': FieldValue.serverTimestamp(),
          },
        });
      });

      if (!startSession) await _auth.signOut();
      return AuthSuccess(profile);
    } on fb.FirebaseAuthException catch (error) {
      await _discard(credential);
      return AuthFailure(_mapError(error.code));
    } catch (error) {
      await _discard(credential);
      debugPrint('signUp failed: $error');
      return const AuthFailure(AuthError.unknown);
    }
  }

  /// Removes a half-created account so a failed sign-up leaves nothing behind.
  Future<void> _discard(fb.UserCredential? credential) async {
    try {
      await credential?.user?.delete();
    } catch (_) {
      // Already gone, or the token expired. Either way there is nothing left
      // to do and the caller is being told the sign-up failed regardless.
    }
  }

  @override
  Future<AuthResult> logIn({
    required String username,
    required String password,
  }) async {
    final normalised = AuthRepository.normalise(username);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailFor(normalised),
        password: password,
      );

      final snapshot = await _users.doc(credential.user!.uid).get();
      final data = snapshot.data();
      if (data == null) {
        // An auth user with no profile document should not exist. Signing out
        // is better than dropping someone into a half-built session.
        await _auth.signOut();
        return const AuthFailure(AuthError.unknown);
      }
      return AuthSuccess(UserProfile.fromJson(data));
    } on fb.FirebaseAuthException {
      // Unknown user and wrong password collapse to one error on purpose, so
      // the login screen cannot be used to enumerate who exists.
      return const AuthFailure(AuthError.wrongCredentials);
    }
  }

  @override
  Future<void> logOut() => _auth.signOut();

  @override
  Stream<String?> watchCommunityId(String uid) => _users
      .doc(uid)
      .snapshots()
      .map(
        (d) => switch (d.data()?['communityId']) {
          final String id when id.isNotEmpty => id,
          _ => null,
        },
      )
      .distinct();

  @override
  Future<void> updateProfile(UserProfile profile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Only the fields a person owns. Scores and counts are server-written and
    // the rules reject them from a client anyway.
    await _users.doc(uid).update({
      'displayName': profile.displayName,
      'nameLower': profile.displayName.toLowerCase(),
      'gender': profile.gender.name,
      'language': profile.language.code,
      'avatarId': profile.avatarId,
    });
  }

  @override
  Future<AuthResult> changePassword({
    required String current,
    required String next,
  }) async {
    final user = _auth.currentUser;
    final profile = await currentUser();
    if (user == null || profile == null) {
      return const AuthFailure(AuthError.unknown);
    }
    if (next.length < AuthRepository.minPasswordLength) {
      return const AuthFailure(AuthError.weakPassword);
    }

    try {
      // Firebase asks for a recent sign-in before a password change anyway;
      // signing in again with the current password is both that and the
      // proof that the person holding the phone knows it.
      await user.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(
          email: _emailFor(profile.username),
          password: current,
        ),
      );
      await user.updatePassword(next);
      return AuthSuccess(profile);
    } on fb.FirebaseAuthException catch (error) {
      debugPrint('password change failed: ${error.code}');
      return AuthFailure(_mapError(error.code));
    }
  }

  @override
  Future<AuthError?> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    // The address on the sign-in itself, not one rebuilt from the profile: if
    // an earlier attempt got as far as erasing the profile, this is the only
    // place the username is left.
    final email = user?.email;
    if (user == null || email == null) return AuthError.unknown;

    final eraser = _newEraser();
    try {
      await user.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(email: email, password: password),
      );
      // Forced, so the token carries the sign-in that just happened. The
      // worker refuses one from an older sign-in.
      final token = await user.getIdToken(true);
      if (token == null) return AuthError.unknown;

      await eraser.erase(token);
      // The sign-in goes last, and deleting it also signs out. Deleted any
      // earlier, a failure part-way would leave data nobody could ask to
      // have erased.
      await user.delete();
      return null;
    } on fb.FirebaseAuthException catch (error) {
      debugPrint('delete account failed: ${error.code}');
      return _mapError(error.code);
    } on AccountEraseFailed catch (error) {
      debugPrint('delete account failed: $error');
      return AuthError.unknown;
    } finally {
      eraser.close();
    }
  }

  AuthError _mapError(String code) => switch (code) {
    'wrong-password' ||
    'invalid-credential' ||
    'user-mismatch' => AuthError.wrongCredentials,
    'too-many-requests' => AuthError.tooManyAttempts,
    'email-already-in-use' ||
    'username-already-in-use' => AuthError.usernameTaken,
    'weak-password' => AuthError.weakPassword,
    'invalid-email' => AuthError.invalidUsername,
    _ => AuthError.unknown,
  };
}
