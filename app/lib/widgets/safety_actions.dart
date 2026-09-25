import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';

/// Asks, then blocks. Shared by profiles and conversations so the warning is
/// the same wherever it is given: what blocking does, and that they will not
/// be told. Returns true if the block went through.
Future<bool> confirmBlock(
  BuildContext context, {
  required String otherUid,
  required String otherUsername,
}) async {
  final s = context.s;
  final session = context.session;
  final safety = InboxScope.read(context)?.safety;
  final messenger = ScaffoldMessenger.of(context);
  final me = session.uid;
  final meUsername = session.profile?.username;
  if (safety == null || me == null || meUsername == null) return false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.elevated,
      title: Text(s.blockTitle(otherUsername)),
      content: Text(s.blockBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.loss),
          child: Text(s.block),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  try {
    await safety.block(
      me: me,
      meUsername: meUsername,
      otherUid: otherUid,
      otherUsername: otherUsername,
    );
    messenger.showSnackBar(SnackBar(content: Text(s.blocked(otherUsername))));
    return true;
  } catch (e) {
    debugPrint('block failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    return false;
  }
}

/// Lifts a block without asking: undoing a block is always safe.
Future<void> unblock(
  BuildContext context, {
  required String otherUid,
  required String otherUsername,
}) async {
  final s = context.s;
  final me = context.session.uid;
  final safety = InboxScope.read(context)?.safety;
  final messenger = ScaffoldMessenger.of(context);
  if (safety == null || me == null) return;
  try {
    await safety.unblock(me, otherUid);
    messenger.showSnackBar(SnackBar(content: Text(s.unblocked(otherUsername))));
  } catch (e) {
    debugPrint('unblock failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
  }
}
