import 'dart:async';

import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../models/app_config.dart';

/// Follows what the admins set and hands it to everything below: the gate,
/// the banner, the pinned post, the blocked words and switches. Without
/// Firestore — or before the first answer — the app is simply itself.
class AppConfigHost extends StatefulWidget {
  const AppConfigHost({
    super.key,
    required this.child,
    this.app,
    this.moderation,
  });

  final Widget child;
  final Stream<AppConfig>? app;
  final Stream<Moderation>? moderation;

  @override
  State<AppConfigHost> createState() => _AppConfigHostState();
}

class _AppConfigHostState extends State<AppConfigHost> {
  AppConfig _config = AppConfig.none;
  Moderation _moderation = Moderation.none;
  StreamSubscription<AppConfig>? _app;
  StreamSubscription<Moderation>? _held;

  @override
  void initState() {
    super.initState();
    _app = widget.app?.listen((c) => setState(() => _config = c));
    _held = widget.moderation?.listen((m) => setState(() => _moderation = m));
  }

  @override
  void dispose() {
    _app?.cancel();
    _held?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppConfigScope(
    config: _config,
    moderation: _moderation,
    child: widget.child,
  );
}

class AppConfigScope extends InheritedWidget {
  const AppConfigScope({
    super.key,
    required this.config,
    required this.moderation,
    required super.child,
  });

  final AppConfig config;
  final Moderation moderation;

  /// What is set — nothing, where there is no host (a test, say).
  static AppConfig configOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppConfigScope>()?.config ??
      AppConfig.none;

  static Moderation moderationOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppConfigScope>()?.moderation ??
      Moderation.none;

  @override
  bool updateShouldNotify(AppConfigScope old) =>
      old.config != config || old.moderation != moderation;
}

/// Whether [text] may be sent as [feature]: not while the admins have it
/// paused, and — with [words] — not with a blocked word in it. When it may
/// not, says why, and what was typed stays where it was.
bool sendAllowed(
  BuildContext context,
  String text, {
  AppFeature? feature,
  bool words = true,
}) {
  final held = AppConfigScope.moderationOf(context);
  final s = context.s;
  final String? why;
  if (feature != null && held.paused(feature)) {
    why = s.pausedBody(s.featureName(feature.key));
  } else if (words) {
    final word = held.firstIn(text);
    why = word == null ? null : s.blockedWord(word);
  } else {
    why = null;
  }
  if (why == null) return true;
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(s.cantSendThis),
      content: Text(why!),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(s.gotIt),
        ),
      ],
    ),
  );
  return false;
}
