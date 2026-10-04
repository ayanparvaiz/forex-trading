import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../firebase/firebase_bootstrap.dart';
import 'score_sync.dart';

/// Asking the admins for a way back in (worker/src/help.js): the app has no
/// password reset, so a username and how to reach them go to the admins,
/// who set a new password once they are sure who is asking.
abstract class PasswordHelp {
  /// True when the request reached the admins.
  Future<bool> ask({
    required String username,
    required String contact,
    String note = '',
  });
}

class WorkerPasswordHelp implements PasswordHelp {
  WorkerPasswordHelp({Uri? endpoint, HttpClient? client})
    : endpoint = endpoint ?? helpEndpoint,
      _client = client ?? HttpClient();

  final Uri endpoint;
  final HttpClient _client;

  @override
  Future<bool> ask({
    required String username,
    required String contact,
    String note = '',
  }) async {
    try {
      final request = await _client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 20));
      request.headers.contentType = ContentType.json;
      // See WorkerScoreSync: Cloudflare refuses some stock client strings.
      request.headers.set(HttpHeaders.userAgentHeader, 'forex-trading-app');
      request.write(
        jsonEncode({'username': username, 'contact': contact, 'note': note}),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Where the request goes: the same worker as [statsEndpoint].
final Uri helpEndpoint = statsEndpoint.resolve('/help');

/// On Firebase, where there are admins to ask; not on the local demo.
PasswordHelp? buildPasswordHelp() =>
    FirebaseBootstrap.isReady ? WorkerPasswordHelp() : null;
