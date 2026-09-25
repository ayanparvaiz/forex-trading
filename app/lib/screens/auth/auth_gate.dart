import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../../data/account_scope.dart';
import '../../data/firestore_trade_repository.dart';
import '../../data/score_sync.dart';
import '../../data/session_controller.dart';
import '../../firebase/firebase_bootstrap.dart';
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
        store.attach(buildTradeRepository(uid), scores: _scoreSyncFor());
      }
    });
  }

  /// The worker that writes this account's leaderboard row, when there is a
  /// shared leaderboard to write it to.
  ScoreSync _scoreSyncFor() {
    if (!FirebaseBootstrap.isReady) return const NoScoreSync();
    return WorkerScoreSync(
      endpoint: statsEndpoint,
      idToken: () async => fb.FirebaseAuth.instance.currentUser?.getIdToken(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (session.isRestoring) {
      return const SplashScreen();
    }

    // Keyed so switching accounts tears down the old screens rather than
    // reusing their state.
    return session.isSignedIn
        ? AppShell(key: ValueKey(session.profile!.username))
        : const LoginScreen();
  }
}
