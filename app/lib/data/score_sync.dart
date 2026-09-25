import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Asks the stats worker to recompute this account's leaderboard row.
///
/// The app cannot write its own score — the rules refuse it — so after a
/// trade closes it tells the worker, and the worker reads the trades and
/// writes the numbers. See worker/src/index.js.
abstract class ScoreSync {
  /// Something changed that moves the score. Cheap to call repeatedly.
  void request();

  void dispose();
}

/// For a clone with no Firebase and no worker: there is no shared
/// leaderboard to update, so there is nothing to do.
class NoScoreSync implements ScoreSync {
  const NoScoreSync();

  @override
  void request() {}

  @override
  void dispose() {}
}

class WorkerScoreSync implements ScoreSync {
  WorkerScoreSync({
    required this.endpoint,
    required this.idToken,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  /// The deployed worker. Set in [statsEndpoint].
  final Uri endpoint;

  /// A fresh Firebase ID token for the signed-in user.
  final Future<String?> Function() idToken;

  final HttpClient _client;
  Timer? _pending;
  bool _disposed = false;

  /// How long to wait for more changes before sending.
  ///
  /// A stop and a target can fill on the same tick, and a lesson is usually
  /// written seconds after a close. One request after the burst settles is
  /// the same result as three, for a third of the reads.
  static const _settle = Duration(seconds: 2);

  @override
  void request() => _schedule(_settle);

  void _schedule(Duration after) {
    if (_disposed) return;
    _pending?.cancel();
    _pending = Timer(after, _send);
  }

  Future<void> _send() async {
    if (_disposed) return;

    try {
      final token = await idToken();
      if (token == null) return;

      final request = await _client.postUrl(endpoint);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      // Named rather than left as dart:io's default. Cloudflare's bot check
      // blocks some stock client strings outright — Python's is refused with
      // error 1010 — and whether Dart's stays allowed is not ours to decide.
      request.headers.set(HttpHeaders.userAgentHeader, 'forex-trading-app');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 429) {
        // The worker allows one recompute per account every few seconds.
        // Trying again once the window passes picks up everything that
        // changed in between, so nothing is lost by being told to wait.
        final retry =
            (jsonDecode(body) as Map)['retryAfterMs'] as int? ?? 15000;
        _schedule(Duration(milliseconds: retry + 500));
        return;
      }
      if (response.statusCode != 200) {
        debugPrint('score update refused: ${response.statusCode} $body');
      }
    } catch (error) {
      // Offline, or the worker is down. The next closed trade asks again, and
      // the numbers it writes are computed from every trade — so a missed
      // update is corrected by the next one rather than lost.
      debugPrint('score update failed: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _client.close();
  }
}

/// Where the stats worker is deployed.
///
/// Can be pointed elsewhere at build time with
/// `--dart-define=STATS_ENDPOINT=https://…/recompute`.
final Uri statsEndpoint = Uri.parse(
  const String.fromEnvironment(
    'STATS_ENDPOINT',
    defaultValue:
        'https://forex-trading-stats.forex-trading-stats.workers.dev/recompute',
  ),
);
