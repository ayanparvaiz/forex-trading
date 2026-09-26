import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import '../firebase/firebase_bootstrap.dart';
import 'score_sync.dart';

/// Why the worker did not finish a change to a community.
class CommunityChangeFailed implements Exception {
  const CommunityChangeFailed(this.status);

  /// The worker's HTTP status, or null when it could not be reached or never
  /// said it was done.
  final int? status;

  @override
  String toString() => 'CommunityChangeFailed($status)';
}

/// What only a community's admin can do to other people — remove someone,
/// or delete it and so take everyone out of it.
///
/// Both change other people's profiles, which the rules let nobody write but
/// the worker, so the worker does them (worker/src/community.js) — and only
/// for the admin the community names.
class CommunityAdmin {
  CommunityAdmin({Uri? endpoint, HttpClient? client})
    : endpoint = endpoint ?? communityEndpoint,
      _client = client ?? HttpClient();

  final Uri endpoint;
  final HttpClient _client;

  /// A big community takes more than one request to delete. Far more than
  /// any needs; it only stops a worker that never says done from looping.
  static const _maxCalls = 25;

  /// Takes [uid] out of [community]. Throws [CommunityChangeFailed].
  Future<void> remove({required String community, required String uid}) =>
      _untilDone({'action': 'remove', 'communityId': community, 'uid': uid});

  /// Deletes [community]; everyone in it leaves. Throws
  /// [CommunityChangeFailed].
  Future<void> delete(String community) =>
      _untilDone({'action': 'delete', 'communityId': community});

  Future<void> _untilDone(Map<String, String> change) async {
    for (var i = 0; i < _maxCalls; i++) {
      final (status, body) = await _post(change);
      if (status != 200) throw CommunityChangeFailed(status);
      // {done: false}: this request ran out of room; the next carries on.
      if (body['done'] == true) return;
    }
    throw const CommunityChangeFailed(null);
  }

  Future<(int, Map<String, Object?>)> _post(Map<String, String> change) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) throw const CommunityChangeFailed(401);
      final request = await _client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 20));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        // See WorkerScoreSync: Cloudflare refuses some stock client strings.
        ..set(HttpHeaders.userAgentHeader, 'forex-trading-app');
      request.write(jsonEncode(change));
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      final text = await response.transform(utf8.decoder).join();
      final body = text.isEmpty
          ? const <String, Object?>{}
          : (jsonDecode(text) as Map).cast<String, Object?>();
      return (response.statusCode, body);
    } on CommunityChangeFailed {
      rethrow;
    } catch (_) {
      // Offline, timed out, or not JSON. Trying again starts from what is
      // left, so nothing is half-done in a way that matters.
      throw const CommunityChangeFailed(null);
    }
  }
}

/// Where the worker changes communities: the same worker as [statsEndpoint].
final Uri communityEndpoint = statsEndpoint.resolve('/community');

CommunityAdmin? _built;

/// Null without Firebase: there is no worker, and no communities.
CommunityAdmin? get communityAdmin =>
    FirebaseBootstrap.isReady ? _built ??= CommunityAdmin() : null;
