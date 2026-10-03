import 'dart:async';

import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../models/app_config.dart';

/// Follows what the admins set and hands it to everything below: the gate,
/// the banner, the pinned post, the blocked words. Without Firestore — or
/// before the first answer — the app is simply itself.
class AppConfigHost extends StatefulWidget {
  const AppConfigHost({super.key, required this.child, this.app, this.blocked});

  final Widget child;
  final Stream<AppConfig>? app;
  final Stream<BlockedWords>? blocked;

  @override
  State<AppConfigHost> createState() => _AppConfigHostState();
}

class _AppConfigHostState extends State<AppConfigHost> {
  AppConfig _config = AppConfig.none;
  BlockedWords _blocked = BlockedWords.none;
  StreamSubscription<AppConfig>? _app;
  StreamSubscription<BlockedWords>? _words;

  @override
  void initState() {
    super.initState();
    _app = widget.app?.listen((c) => setState(() => _config = c));
    _words = widget.blocked?.listen((b) => setState(() => _blocked = b));
  }

  @override
  void dispose() {
    _app?.cancel();
    _words?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppConfigScope(config: _config, blocked: _blocked, child: widget.child);
}

class AppConfigScope extends InheritedWidget {
  const AppConfigScope({
    super.key,
    required this.config,
    required this.blocked,
    required super.child,
  });

  final AppConfig config;
  final BlockedWords blocked;

  /// What is set — nothing, where there is no host (a test, say).
  static AppConfig configOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppConfigScope>()?.config ??
      AppConfig.none;

  static BlockedWords blockedOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppConfigScope>()?.blocked ??
      BlockedWords.none;

  @override
  bool updateShouldNotify(AppConfigScope old) =>
      old.config != config || old.blocked != blocked;
}

/// Whether [text] may be sent. When a blocked word is in it, says which and
/// why, and the text stays where it was typed.
bool wordsAllowed(BuildContext context, String text) {
  final word = AppConfigScope.blockedOf(context).firstIn(text);
  if (word == null) return true;
  final s = context.s;
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(s.cantSendThis),
      content: Text(s.blockedWord(word)),
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
