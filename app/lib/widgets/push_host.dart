import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../data/firestore_community_repository.dart';
import '../data/push.dart';
import '../data/session_controller.dart';
import '../screens/chat_screen.dart';
import '../screens/post_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/room_screen.dart';

/// Push notifications for whoever is signed in, and what tapping one opens.
///
/// Sits in MaterialApp.builder beside the inbox, above the Navigator, for the
/// same reason: it has to reach every route. The first sign-in on a phone
/// asks for permission; after that the phone is registered quietly, or not
/// at all if notifications were turned off. Signing out forgets the phone
/// while the account can still do so.
class PushHost extends StatefulWidget {
  const PushHost({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<PushHost> createState() => _PushHostState();
}

class _PushHostState extends State<PushHost> {
  final PushService? _push = pushService;
  SessionController? _session;
  String? _uid;
  String? _language;

  /// A tapped notification waiting for someone to be signed in.
  PushRoute? _pending;
  StreamSubscription<RemoteMessage>? _opened;

  @override
  void initState() {
    super.initState();
    final push = _push;
    if (push == null) return;
    _opened = push.opened.listen((m) => _open(PushRoute.fromData(m.data)));
    push.launchedBy().then((m) {
      if (m != null) _open(PushRoute.fromData(m.data), launched: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.of(context);
    if (!identical(session, _session)) {
      _session?.removeSignOutHook(_forget);
      session.addSignOutHook(_forget);
      _session = session;
    }

    final uid = session.uid;
    final language = session.language.code;
    if (uid != _uid) {
      _uid = uid;
      _language = language;
      if (uid != null) _start(uid, language);
    } else if (uid != null && language != _language) {
      // Notifications come in the reader's language.
      _language = language;
      _relanguage(uid, language);
    }
    _flush();
  }

  Future<void> _start(String uid, String language) async {
    final push = _push;
    if (push == null) return;
    try {
      final on = await push.preference(uid);
      if (on == false) return;
      // The first time on this phone: ask. After that, register quietly.
      if (on == null) {
        await push.enable(uid, language);
      } else {
        await push.attach(uid, language);
      }
    } catch (e) {
      debugPrint('push setup failed: $e');
    }
  }

  Future<void> _relanguage(String uid, String language) async {
    final push = _push;
    if (push == null || await push.preference(uid) != true) return;
    await push.attach(uid, language).catchError((Object _) {});
  }

  Future<void> _forget(String uid) async => _push?.detach(uid);

  void _open(PushRoute? route, {bool launched = false}) {
    if (route == null) return;
    _pending = route;
    // Launched by the tap: let the splash and the sign-in finish first.
    if (launched) {
      Future<void>.delayed(const Duration(milliseconds: 1600), _flush);
    } else {
      _flush();
    }
  }

  void _flush() {
    final route = _pending;
    final nav = widget.navigatorKey.currentContext;
    final session = _session;
    if (route == null ||
        nav == null ||
        session == null ||
        session.uid == null ||
        session.isRestoring) {
      return;
    }
    _pending = null;
    switch (route) {
      case OpenChatRoute(:final chatId, :final otherUid, :final otherUsername):
        openChat(
          nav,
          chatId: chatId,
          otherUid: otherUid,
          otherUsername: otherUsername,
        );
      case OpenRoomRoute():
        openGlobalChat(nav);
      case OpenProfileRoute(:final username):
        openProfile(
          nav,
          username,
          buildCommunityRepository(session.language, viewerUid: session.uid),
        );
      case OpenPostRoute(:final postId):
        openPost(nav, postId);
    }
  }

  @override
  void dispose() {
    _opened?.cancel();
    _session?.removeSignOutHook(_forget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
