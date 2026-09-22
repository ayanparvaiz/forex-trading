import 'package:flutter/material.dart';

import 'data/account_scope.dart';
import 'data/account_store.dart';
import 'data/auth_repository.dart';
import 'data/session_controller.dart';
import 'firebase/firebase_bootstrap.dart';
import 'screens/auth/auth_gate.dart';
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
  late final SessionController _session =
      SessionController(LocalAuthRepository());
  late final AccountStore _store = AccountStore();

  @override
  void initState() {
    super.initState();
    _session.restore();
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
          home: const AuthGate(),
        ),
      ),
    );
  }
}
