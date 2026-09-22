import 'package:flutter/material.dart';

import 'data/account_scope.dart';
import 'data/account_store.dart';
import 'firebase/firebase_bootstrap.dart';
import 'screens/app_shell.dart';
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
  late final AccountStore _store = AccountStore();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccountScope(
      store: _store,
      child: MaterialApp(
        title: 'Forex Trading',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const AppShell(),
      ),
    );
  }
}
