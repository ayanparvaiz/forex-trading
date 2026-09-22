import 'package:flutter/material.dart';

import '../../data/session_controller.dart';
import '../../theme/app_theme.dart';
import '../app_shell.dart';
import 'login_screen.dart';

/// Chooses between the app and the login screen.
///
/// Holds a splash while the stored session is read, so a returning user never
/// sees the login screen flash before being let straight in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (session.isRestoring) {
      return const _Splash();
    }

    // Keyed so switching accounts tears down the old screens rather than
    // reusing their state.
    return session.isSignedIn
        ? AppShell(key: ValueKey(session.profile!.username))
        : const LoginScreen();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📈', style: TextStyle(fontSize: 46)),
            Gap.h16,
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
