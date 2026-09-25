import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/safety_actions.dart';

/// Everyone you have blocked, with a way to unblock each.
class BlockedAccountsScreen extends StatelessWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final blocked = InboxScope.of(context)?.blocked ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(s.blockedAccounts)),
      body: blocked.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.block,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    Gap.h12,
                    Text(
                      s.noBlocked,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: Gap.sm),
              itemCount: blocked.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: Gap.lg, endIndent: Gap.lg),
              itemBuilder: (context, i) {
                final b = blocked[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.elevated,
                    child: Icon(Icons.block, color: AppColors.textMuted),
                  ),
                  title: Text(
                    '@${b.username}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    s.blockedOn(b.blockedAt),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => unblock(
                      context,
                      otherUid: b.uid,
                      otherUsername: b.username,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      side: const BorderSide(color: AppColors.brand),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(s.unblock),
                  ),
                );
              },
            ),
    );
  }
}
