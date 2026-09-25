import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_bootstrap.dart';
import 'score_sync.dart';

/// Tells the worker something just happened, so it can let the people it
/// concerns know on their phones — once it has checked (worker/src/notify.js).
///
/// Fire and forget: a notification that does not go out costs nothing the
/// app shows, and the thing itself has already happened.
class PushNotifier {
  PushNotifier({Uri? endpoint, HttpClient? client})
    : endpoint = endpoint ?? notifyEndpoint,
      _client = client ?? HttpClient();

  final Uri endpoint;
  final HttpClient _client;

  void message(String chatId, String messageId) =>
      _send({'type': 'message', 'chatId': chatId, 'messageId': messageId});

  void room(String roomId, String messageId) =>
      _send({'type': 'room', 'roomId': roomId, 'messageId': messageId});

  void connectionRequest(String pair) =>
      _send({'type': 'connectionRequest', 'pair': pair});

  void connectionAccepted(String pair) =>
      _send({'type': 'connectionAccepted', 'pair': pair});

  void post(String postId) => _send({'type': 'post', 'postId': postId});

  Future<void> _send(Map<String, String> event) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return;
      final request = await _client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 15));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        // See WorkerScoreSync: Cloudflare refuses some stock client strings.
        ..set(HttpHeaders.userAgentHeader, 'forex-trading-app');
      request.write(jsonEncode(event));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      await response.drain<void>();
    } catch (e) {
      debugPrint('notify failed: $e');
    }
  }
}

/// Where the worker announces things: the same worker as [statsEndpoint].
final Uri notifyEndpoint = statsEndpoint.resolve('/notify');

PushNotifier? _built;

/// Null without Firebase: there is no worker to tell.
PushNotifier? get pushNotifier =>
    FirebaseBootstrap.isReady ? _built ??= PushNotifier() : null;
