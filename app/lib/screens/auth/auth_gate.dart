import 'package:flutter/material.dart';

import '../../data/community_repository.dart';
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
    // Keyed so switching accounts tears down the old screens rather than
    // reusing their state.
    return session.isSignedIn
        ? AppShell(key: ValueKey(session.profile!.username))
        : const LoginScreen();
  }
}
