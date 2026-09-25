import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_bootstrap.dart';

/// Where tapping a push notification takes you.
sealed class PushRoute {
  const PushRoute();

  /// Read from the notification's data, as worker/src/notify.js writes it.
  /// Null for one that opens nothing in particular — the morning reminder.
  static PushRoute? fromData(Map<String, dynamic> data) {
    String? text(String key) {
      final v = data[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    return switch (data['type']) {
      'message' when text('chatId') != null && text('otherUid') != null =>
        OpenChatRoute(
          chatId: text('chatId')!,
          otherUid: text('otherUid')!,
          otherUsername: text('otherUsername') ?? '',
        ),
      'room' when text('roomId') != null => OpenRoomRoute(text('roomId')!),
      'profile' when text('username') != null => OpenProfileRoute(
        text('username')!,
      ),
      'post' when text('postId') != null => OpenPostRoute(text('postId')!),
      _ => null,
    };
  }
}

class OpenChatRoute extends PushRoute {
  const OpenChatRoute({
    required this.chatId,
    required this.otherUid,
    required this.otherUsername,
  });

  final String chatId;
  final String otherUid;
  final String otherUsername;
}

class OpenRoomRoute extends PushRoute {
  const OpenRoomRoute(this.roomId);
  final String roomId;
}

class OpenProfileRoute extends PushRoute {
  const OpenProfileRoute(this.username);
  final String username;
}

class OpenPostRoute extends PushRoute {
  const OpenPostRoute(this.postId);
  final String postId;
}

/// Push notifications on this phone.
///
/// The phone's FCM token is kept at users/{uid}/devices/{token}, which is
/// what the worker sends to; the morning reminder comes from a topic. Turning
/// notifications off — or signing out — removes both, so a phone never gets
/// another account's notifications, or any after saying no.
///
/// On/off is remembered per account on this phone, like the phone's own
/// notification settings.
class PushService {
  PushService({FirebaseMessaging? messaging, FirebaseFirestore? firestore})
    : _messaging = messaging ?? FirebaseMessaging.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  static const _languages = ['bn', 'en'];

  String? _uid;
  String? _language;
  String? _token;
  StreamSubscription<String>? _refresh;

  static String _key(String uid) => 'push.enabled.$uid';

  CollectionReference<Map<String, dynamic>> _devices(String uid) =>
      _db.collection('users').doc(uid).collection('devices');

  /// Whether notifications are on for [uid] here; null if never decided.
  Future<bool?> preference(String uid) async =>
      (await SharedPreferences.getInstance()).getBool(_key(uid));

  Future<void> _remember(String uid, bool on) async =>
      (await SharedPreferences.getInstance()).setBool(_key(uid), on);

  /// Turns notifications on, asking the phone first. False if it says no —
  /// then only the phone's own Settings can change that.
  Future<bool> enable(String uid, String language) async {
    final settings = await _messaging.requestPermission();
    final allowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    await _remember(uid, allowed);
    if (allowed) await attach(uid, language);
    return allowed;
  }

  /// Registers this phone for [uid], for someone who has already said yes.
  /// Also how a change of language reaches the worker and the topics.
  Future<void> attach(String uid, String language) async {
    _uid = uid;
    _language = language;
    final token = await _currentToken();
    if (token == null) return;
    await _save(token);
    await _followMorningReminder(language);
    _refresh ??= _messaging.onTokenRefresh.listen((fresh) async {
      final uid = _uid;
      final old = _token;
      if (uid == null) return;
      if (old != null && old != fresh) {
        await _devices(uid).doc(old).delete().catchError((Object _) {});
      }
      await _save(
        fresh,
      ).catchError((Object e) => debugPrint('push token refresh failed: $e'));
    });
  }

  /// Turned off in Settings: nothing more to this phone for [uid].
  Future<void> disable(String uid) async {
    await _remember(uid, false);
    await detach(uid);
  }

  /// Forgets this phone for [uid], here and on the server. Signing out does
  /// this too — the token goes, so nothing for the old account can follow.
  Future<void> detach(String uid) async {
    final token = _token;
    _token = null;
    _uid = null;
    await _refresh?.cancel();
    _refresh = null;
    if (token != null) {
      await _devices(uid)
          .doc(token)
          .delete()
          .catchError(
            (Object e) => debugPrint('forgetting this phone failed: $e'),
          );
    }
    for (final l in _languages) {
      await _messaging
          .unsubscribeFromTopic('daily_$l')
          .catchError((Object _) {});
    }
    await _messaging.deleteToken().catchError((Object _) {});
  }

  /// A notification tapped while the app was open or in the background.
  Stream<RemoteMessage> get opened => FirebaseMessaging.onMessageOpenedApp;

  /// The notification that launched the app, if one did.
  Future<RemoteMessage?> launchedBy() => _messaging.getInitialMessage();

  Future<String?> _currentToken() async {
    try {
      if (Platform.isIOS) {
        // FCM needs Apple's token first. It can take a moment after launch,
        // and never comes where Apple push is not set up (see README).
        for (var i = 0; i < 5; i++) {
          if (await _messaging.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (await _messaging.getAPNSToken() == null) return null;
      }
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('no push token: $e');
      return null;
    }
  }

  Future<void> _save(String token) async {
    final uid = _uid;
    if (uid == null) return;
    _token = token;
    await _devices(uid).doc(token).set({
      'uid': uid,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'language': _language ?? 'bn',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// The reminder in the reader's language, and not the other.
  Future<void> _followMorningReminder(String language) async {
    for (final l in _languages) {
      final topic = 'daily_$l';
      await (l == language
              ? _messaging.subscribeToTopic(topic)
              : _messaging.unsubscribeFromTopic(topic))
          .catchError((Object e) => debugPrint('topic $topic: $e'));
    }
  }
}

/// On a phone with Firebase; nothing anywhere else.
PushService? _built;
PushService? get pushService {
  if (!FirebaseBootstrap.isReady || !(Platform.isIOS || Platform.isAndroid)) {
    return null;
  }
  return _built ??= PushService();
}
