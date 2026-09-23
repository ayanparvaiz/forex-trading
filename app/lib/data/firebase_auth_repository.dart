import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../i18n/strings.dart';
import '../models/user_profile.dart';
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
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Domain for the synthetic addresses. Not a real mail domain, and never
  /// resolved — using a domain nobody owns would risk it becoming real later.
  static const _domain = 'users.forex-9f21b.app';

  static String _emailFor(String username) => '$username@$_domain';

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

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
          // Server-owned from here on. Written once at creation so the rules
          // can compare against them on every later update.
          'disciplineScore': 100,
          'badgePoints': 0,
          'tradeCount': 0,
          'winRate': 0,
          'journalStreak': 0,
          'totalR': 0,
          'createdAtServer': FieldValue.serverTimestamp(),
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
  Future<void> updateProfile(UserProfile profile) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Only the fields a person owns. Scores and counts are server-written and
    // the rules reject them from a client anyway.
    await _users.doc(uid).update({
      'displayName': profile.displayName,
      'gender': profile.gender.name,
      'language': profile.language.code,
      'avatarId': profile.avatarId,
    });
  }

  AuthError _mapError(String code) => switch (code) {
        'email-already-in-use' || 'username-already-in-use' =>
          AuthError.usernameTaken,
        'weak-password' => AuthError.weakPassword,
        'invalid-email' => AuthError.invalidUsername,
        _ => AuthError.unknown,
      };
}
