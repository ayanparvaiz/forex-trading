import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';

/// Asks how long to mute a conversation for — WhatsApp's three choices —
/// and returns when the mute should end, or null if dismissed.
Future<DateTime?> pickMuteUntil(BuildContext context) {
  final s = context.s;
  final now = DateTime.now();
  final choices = [
    (s.mute8Hours, now.add(const Duration(hours: 8))),
    (s.mute1Week, now.add(const Duration(days: 7))),
    (s.muteAlways, ChatPrefs.forever),
  ];
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 6),
            child: Text(
              s.muteNotifications,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
            child: Text(
              s.muteExplain,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          for (final (label, until) in choices)
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(label),
              onTap: () => Navigator.of(sheet).pop(until),
            ),
          const SizedBox(height: Gap.sm),
        ],
      ),
    ),
  );
}

/// Asks how long, mutes [chatId], and says until when.
Future<void> muteChat(
  BuildContext context,
  ChatInbox inbox,
  String chatId,
) async {
  final s = context.s;
  final messenger = ScaffoldMessenger.of(context);
  final until = await pickMuteUntil(context);
  if (until == null) return;
  await inbox.repository
      .mute(chatId, inbox.uid, until)
      .catchError((Object e) => debugPrint('mute failed: $e'));
  messenger.showSnackBar(
    SnackBar(content: Text(s.mutedUntil(until, DateTime.now()))),
  );
}

Future<void> unmuteChat(ChatInbox inbox, String chatId) => inbox.repository
    .unmute(chatId, inbox.uid)
    .catchError((Object e) => debugPrint('unmute failed: $e'));

/// A menu row that mutes, or — when muted — unmutes and says until when.
class MuteMenuRow extends StatelessWidget {
  const MuteMenuRow({
    super.key,
    required this.s,
    required this.prefs,
    required this.now,
  });

  final Strings s;
  final ChatPrefs prefs;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final muted = prefs.mutedAt(now);
    return Row(
      children: [
        Icon(
          muted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          size: 19,
        ),
        Gap.w12,
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(muted ? s.unmute : s.muteNotifications),
              if (muted)
                Text(
                  s.mutedUntil(prefs.mutedUntil!, now),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
