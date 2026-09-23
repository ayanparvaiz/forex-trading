import 'package:flutter/material.dart';

import '../../data/account_scope.dart';
import '../../data/community_repository.dart';
import '../../data/firestore_trade_repository.dart';
import '../../data/session_controller.dart';
import '../app_shell.dart';
import '../splash_screen.dart';
import 'login_screen.dart';

/// Chooses between the app and the login screen.
///
/// Holds a splash while the stored session is read, so a returning user never
/// sees the login screen flash before being let straight in.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _graphSeededFor;

  /// The account whose journal is currently loaded, so it loads once.
  String? _journalFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Runs whenever the session changes, which is the moment the account's
    // trades become knowable. Deferred to after the frame because attaching
    // notifies the store, and notifying during a build is not allowed.
    final uid = SessionScope.of(context).uid;
    if (uid == _journalFor) return;
    _journalFor = uid;

    final store = AccountScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (uid == null) {
        store.detach();
      } else {
        store.attach(buildTradeRepository(uid));
      }
    });
  }

  /// Gives a new account a starting web of connections, requests and visitors,
  /// so the profile screen is not an empty room the first time it is opened.
  void _seedGraphOnce(SessionController session) {
    final username = session.profile?.username;
    if (username == null || _graphSeededFor == username) return;
    _graphSeededFor = username;

    LocalCommunityRepository(language: session.language).seedGraph(username);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (session.isRestoring) {
      return const SplashScreen();
    }

    _seedGraphOnce(session);

    // Keyed so switching accounts tears down the old screens rather than
    // reusing their state.
    return session.isSignedIn
        ? AppShell(key: ValueKey(session.profile!.username))
        : const LoginScreen();
  }
}
