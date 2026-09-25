import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'score_sync.dart';

/// Why the worker did not finish erasing an account.
class AccountEraseFailed implements Exception {
  const AccountEraseFailed(this.status);

  /// The worker's HTTP status, or null when it could not be reached or never
  /// said it was done.
  final int? status;

  @override
  String toString() => 'AccountEraseFailed($status)';
}

/// Asks the worker to erase the signed-in account from Firestore.
///
/// Most of an account is not its own to delete under the rules — a
/// conversation belongs to two people, a like sits on someone else's post —
/// so the worker does it with a service account. See worker/src/erase.js.
class AccountEraser {
  AccountEraser({Uri? endpoint, HttpClient? client})
    : endpoint = endpoint ?? deleteAccountEndpoint,
      _client = client ?? HttpClient();

  final Uri endpoint;
  final HttpClient _client;

  /// One request does a bounded amount of work, so a large account takes
  /// several. Far more than any real account needs; it only stops a worker
  /// that never says done from looping forever.
  static const _maxCalls = 25;

  /// Calls until the worker says everything is gone.
  ///
  /// [idToken] has to come from a sign-in in the last few minutes — the
  /// worker refuses an old one. Throws [AccountEraseFailed].
  Future<void> erase(String idToken) async {
    for (var i = 0; i < _maxCalls; i++) {
      final (status, body) = await _post(idToken);
      if (status != 200) throw AccountEraseFailed(status);
      // {done: false}: this request ran out of room. The next one carries on
      // from where it stopped.
      if (body['done'] == true) return;
    }
    throw const AccountEraseFailed(null);
  }

  Future<(int, Map<String, Object?>)> _post(String idToken) async {
    try {
      final request = await _client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      // See WorkerScoreSync: Cloudflare refuses some stock client strings.
      request.headers.set(HttpHeaders.userAgentHeader, 'forex-trading-app');
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      final text = await response.transform(utf8.decoder).join();
      final body = text.isEmpty
          ? const <String, Object?>{}
          : (jsonDecode(text) as Map).cast<String, Object?>();
      return (response.statusCode, body);
    } catch (_) {
      // Offline, timed out, or not JSON. Nothing is half-done in a way that
      // matters: trying again starts from what is left.
      throw const AccountEraseFailed(null);
    }
  }

  void close() => _client.close();
}

/// Where the worker erases accounts: the same worker as [statsEndpoint].
final Uri deleteAccountEndpoint = statsEndpoint.resolve('/delete-account');
