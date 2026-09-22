import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Brings Firebase up, and lets the app run without it.
///
/// Initialised with no `options`, on purpose. On Android and iOS the native
/// config files supply everything, so `firebase_options.dart` — which carries
/// the API keys and is therefore kept out of version control — never has to be
/// imported by committed code. Adding a web or desktop target later is the only
/// reason that would change.
///
/// A fresh clone has no config at all, so `initializeApp` throws. That must not
/// stop the app starting: every screen works on the mock feed, and a
/// contributor should see the whole UI before they own a Firebase project.
class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool _ready = false;

  /// True once Firebase is live. When false, the app is on local mock data.
  static bool get isReady => _ready;

  static Future<void> ensureInitialized() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (error) {
      _ready = false;
      debugPrint(
        'Firebase unavailable, running on mock data. '
        'Run `flutterfire configure` to connect a project. ($error)',
      );
    }
  }
}
