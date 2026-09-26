import 'package:flutter/widgets.dart';

import '../i18n/strings.dart';
import '../models/user_profile.dart';
import 'auth_repository.dart';

/// Who is signed in, and what language the app is speaking.
///
/// Language lives here rather than on the profile alone because it is needed
/// before anyone has an account: the first step of sign-up is picking it, and
/// every screen after that has to obey immediately.
class SessionController extends ChangeNotifier {
  SessionController(this._auth);

  final AuthRepository _auth;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  /// The account id behind the profile. Notifications and security rules key
  /// off this rather than the username.
  String? _uid;
  String? get uid => _uid;

  bool get isSignedIn => _profile != null;

  /// English until someone chooses: the first screen a new person sees is
  /// in English, and Bangla is one tap away on it.
  AppLanguage _language = AppLanguage.en;
  AppLanguage get language => _language;

  Strings get strings => Strings(_language);

  /// True until the stored session has been checked, so the app can hold a
  /// splash instead of flashing the login screen at a signed-in user.
  bool _restoring = true;
  bool get isRestoring => _restoring;

  Future<void> restore() async {
    _profile = await _auth.currentUser();
    _uid = await _auth.currentUid();
    if (_profile != null) _language = _profile!.language;
    _restoring = false;
    notifyListeners();
  }

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();

    final profile = _profile;
    if (profile != null) {
      _profile = profile.copyWith(language: language);
      _auth.updateProfile(_profile!);
    }
  }

  Future<bool> isUsernameAvailable(String username) =>
      _auth.isUsernameAvailable(username);

  Future<List<String>> suggestUsernames(String base) =>
      _auth.suggestUsernames(base);

  Future<AuthResult> signUp({
    required String username,
    required String password,
    required String displayName,
    required Gender gender,
    required int avatarId,
    required String termsVersion,
  }) async {
    final result = await _auth.signUp(
      username: username,
      password: password,
      displayName: displayName,
      gender: gender,
      language: _language,
      avatarId: avatarId,
      termsVersion: termsVersion,
    );
    if (result is AuthSuccess) {
      _profile = result.profile;
      _uid = await _auth.currentUid();
      notifyListeners();
    }
    return result;
  }

  Future<AuthResult> logIn({
    required String username,
    required String password,
  }) async {
    final result = await _auth.logIn(username: username, password: password);
    if (result is AuthSuccess) {
      _profile = result.profile;
      _language = result.profile.language;
      _uid = await _auth.currentUid();
      notifyListeners();
    }
    return result;
  }

  /// Work that has to happen while still signed in, just before signing
  /// out — forgetting this phone for push notifications. Also run after an
  /// account is deleted, for whatever of it does not need the account.
  final List<Future<void> Function(String uid)> _signOutHooks = [];

  void addSignOutHook(Future<void> Function(String uid) hook) =>
      _signOutHooks.add(hook);

  void removeSignOutHook(Future<void> Function(String uid) hook) =>
      _signOutHooks.remove(hook);

  Future<void> _runSignOutHooks(String? uid) async {
    if (uid == null) return;
    for (final hook in List.of(_signOutHooks)) {
      try {
        await hook(uid);
      } catch (e) {
        debugPrint('sign-out hook failed: $e');
      }
    }
  }

  Future<void> logOut() async {
    await _runSignOutHooks(_uid);
    await _auth.logOut();
    _profile = null;
    _uid = null;
    notifyListeners();
  }

  Future<AuthResult> changePassword({
    required String current,
    required String next,
  }) => _auth.changePassword(current: current, next: next);

  /// Deletes the account for good. Null on success, and then nobody is
  /// signed in — the app falls back to the login screen.
  Future<AuthError?> deleteAccount({required String password}) async {
    final uid = _uid;
    final error = await _auth.deleteAccount(password: password);
    if (error == null) {
      await _runSignOutHooks(uid);
      _profile = null;
      _uid = null;
      notifyListeners();
    }
    return error;
  }

  /// Joined, switched or left a community: already written with the
  /// membership, so this only brings the profile here up to date.
  void setCommunity(String? id) {
    final profile = _profile;
    if (profile == null || profile.communityId == id) return;
    _profile = profile.inCommunity(id);
    notifyListeners();
  }

  /// Shows the change at once, and takes it back if the write fails.
  ///
  /// Waiting for the server before showing a new avatar would make the edit
  /// feel broken; keeping it after the server refused would show a name that
  /// nobody else can see. Rethrows so the caller can say it did not save.
  Future<void> updateProfile(UserProfile profile) async {
    final before = _profile;
    final languageBefore = _language;
    _profile = profile;
    _language = profile.language;
    notifyListeners();

    try {
      await _auth.updateProfile(profile);
    } catch (_) {
      _profile = before;
      _language = languageBefore;
      notifyListeners();
      rethrow;
    }
  }
}

/// Puts the [SessionController] in the tree and rebuilds on every change.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope found above this widget.');
    return scope!.notifier!;
  }
}

/// `context.s.navTrade` reads better than building a Strings by hand in every
/// build method, and it makes a screen that forgot to localise obvious.
extension StringsContext on BuildContext {
  Strings get s => SessionScope.of(this).strings;
  SessionController get session => SessionScope.of(this);
}
