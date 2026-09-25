import 'package:flutter/material.dart';

import 'data/account_scope.dart';
import 'data/account_store.dart';
import 'data/auth_repository.dart';
import 'data/firebase_auth_repository.dart';
import 'data/seed_accounts.dart';
import 'data/session_controller.dart';
import 'firebase/firebase_bootstrap.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/inbox_host.dart';

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
  /// Firestore when it is reachable, on-device storage when it is not.
  ///
  /// A fresh clone with no Firebase config still runs the whole app, which is
  /// what makes the project contributable without an account.
  late final AuthRepository _auth = FirebaseBootstrap.isReady
      ? FirebaseAuthRepository()
      : LocalAuthRepository();

  late final SessionController _session = SessionController(_auth);
  late final AccountStore _store = AccountStore();
  final _navigator = GlobalKey<NavigatorState>();

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

    // Demo accounts are only seeded into local storage. On Firestore the
    // twenty accounts are seeded once, server-side — creating twenty auth
    // users from a phone would be both slow and wrong.
    final auth = _auth;
    if (auth is LocalAuthRepository) {
      debugPrint('Auth backend: on-device storage (Firebase unavailable).');
      await SeedAccounts.ensureSeeded(auth);
    } else {
      debugPrint('Auth backend: Firestore.');
    }

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
          navigatorKey: _navigator,
          // Above the Navigator, so every route — tabs, conversations,
          // profiles — can reach the inbox, and a new-message banner draws
          // over whichever one is showing.
          builder: (context, child) =>
              InboxHost(navigatorKey: _navigator, child: child!),
          home: _booting ? const SplashScreen() : const AuthGate(),
        ),
      ),
    );
  }
}
