import 'package:flutter/material.dart';

import 'data/account_scope.dart';
import 'data/account_store.dart';
import 'data/auth_repository.dart';
import 'data/seed_accounts.dart';
import 'data/session_controller.dart';
import 'firebase/firebase_bootstrap.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never blocks startup. Without a Firebase config the app runs entirely on
  // the mock feed, which is exactly what a fresh clone should do.
  await FirebaseBootstrap.ensureInitialized();

  runApp(const ForexTradingApp());
}

class ForexTradingApp extends StatefulWidget {
  const ForexTradingApp({super.key});

  @override
  State<ForexTradingApp> createState() => _ForexTradingAppState();
}

class _ForexTradingAppState extends State<ForexTradingApp> {
  final LocalAuthRepository _auth = LocalAuthRepository();
  late final SessionController _session = SessionController(_auth);
  late final AccountStore _store = AccountStore();

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// How long the splash stays up at minimum.
  ///
  /// Restoring a session takes milliseconds, so without a floor the intro
  /// animation would be a flicker. Matched to the animation's length: long
  /// enough to land, short enough that nobody waits on it.
  static const _minimumSplash = Duration(milliseconds: 1250);

  /// True until both the startup work and the splash floor are done.
  ///
  /// The floor has to gate what is on screen, not just trigger a rebuild —
  /// restore() finishes in milliseconds and would otherwise swap the splash
  /// out before its first frame had drawn.
  bool _booting = true;

  Future<void> _start() async {
    final held = Future<void>.delayed(_minimumSplash);

    // Populate the twenty demo accounts before restoring the session, so the
    // leaderboard and feed are never empty on a fresh install. Idempotent, and
    // it leaves an existing session alone.
    await SeedAccounts.ensureSeeded(_auth);
    await _session.restore();

    // Real work and the floor run together, so a slow start costs nothing
    // extra — the splash is already up.
    await held;
    if (mounted) setState(() => _booting = false);
  }

  @override
  void dispose() {
    _store.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _session,
      child: AccountScope(
        store: _store,
        child: MaterialApp(
          title: 'Forex Trading',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: _booting ? const SplashScreen() : const AuthGate(),
        ),
      ),
    );
  }
}
