import 'package:flutter/material.dart';

import '../data/session_controller.dart';
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
