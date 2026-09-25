import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/firestore_community_repository.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bits.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

/// Your conversations, most recent first.
///
/// Everyone you have a connection with is here — the request itself opens the
/// conversation — ordered by the last thing said.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  /// Keeps "active now" dots honest when nothing new arrives: someone who
  /// closed the app drops off within a couple of minutes even if the list
  /// itself does not change.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final inbox = InboxScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.messages)),
      body: switch (inbox) {
        null => _Empty(
          icon: Icons.cloud_off_outlined,
          title: s.messagingNeedsServer,
        ),
        ChatInbox(loaded: false) => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.brand,
          ),
        ),
        ChatInbox(error: final Object _) when inbox.threads.isEmpty => _Empty(
          icon: Icons.cloud_off_outlined,
          title: s.couldNotLoad,
        ),
        ChatInbox(threads: []) => _Empty(
          icon: Icons.chat_bubble_outline_rounded,
          title: s.noChatsTitle,
          hint: s.noChatsHint,
        ),
        final ChatInbox inbox => ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          itemCount: inbox.threads.length,
          itemBuilder: (context, i) =>
              _ThreadRow(thread: inbox.threads[i], inbox: inbox, s: s),
        ),
      },
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.thread,
    required this.inbox,
    required this.s,
  });

  final ChatThread thread;
  final ChatInbox inbox;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final me = inbox.uid;
    final myUsername = context.session.profile?.username ?? '';
    final otherUid = thread.otherUid(me);
    final otherUsername = thread.otherUsername(myUsername);
    final partner = inbox.partner(otherUid);
    final unread = thread.unreadFor(me);
    final now = DateTime.now();
    final active =
        presenceOf(inbox.lastActive(otherUid), now) == Presence.activeNow;
    final last = thread.lastMessage;
    final mine = last?.senderUid == me;

    final preview = switch (last) {
      null => s.sayHi,
      ChatPreview(unsent: true) => mine ? s.youUnsent : s.theyUnsent,
      final ChatPreview p => mine ? '${s.youPrefix}${p.text}' : p.text,
    };

    return InkWell(
      onTap: () => openChat(
        context,
        chatId: thread.id,
        otherUid: otherUid,
        otherUsername: otherUsername,
      ),
      onLongPress: () => _actions(context, otherUsername, unread > 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 10),
        child: Row(
          children: [
            partner == null
                ? Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.elevated,
                      shape: BoxShape.circle,
                    ),
                  )
                : ChatAvatar(
                    avatarId: partner.avatarId,
                    activeNow: active,
                    size: 52,
                  ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partner?.name.isNotEmpty == true
                              ? partner!.name
                              : '@$otherUsername',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        s.threadTime(thread.updatedAt, now),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: unread > 0
                              ? AppColors.profit
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (mine && last != null && !last.unsent) ...[
                        MessageTicks(
                          status: statusOf(
                            ChatMessage(
                              id: last.id,
                              senderUid: last.senderUid,
                              text: last.text,
                              sentAt: last.sentAt,
                              unsent: last.unsent,
                              pending: false,
                            ),
                            thread,
                            me,
                          ),
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: last == null || last.unsent
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: unread > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        Gap.w8,
                        Container(
                          constraints: const BoxConstraints(minWidth: 21),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.profit,
                            borderRadius: Radii.pill,
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.bg,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _actions(
    BuildContext context,
    String otherUsername,
    bool isUnread,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: Gap.sm),
            ListTile(
              leading: Icon(
                isUnread
                    ? Icons.mark_chat_read_outlined
                    : Icons.mark_chat_unread_outlined,
              ),
              title: Text(isUnread ? s.markRead : s.markUnread),
              onTap: () =>
                  Navigator.of(sheet).pop(isUnread ? 'read' : 'unread'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(s.viewProfile),
              onTap: () => Navigator.of(sheet).pop('profile'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    final me = inbox.uid;
    switch (action) {
      case 'unread':
        await inbox.repository
            .markUnread(thread.id, me)
            .catchError((Object e) => debugPrint('mark unread failed: $e'));
      case 'read':
        await inbox.repository
            .markRead(thread.id, me)
            .catchError((Object e) => debugPrint('mark read failed: $e'));
      case 'profile':
        openProfile(
          context,
          otherUsername,
          buildCommunityRepository(
            context.session.language,
            viewerUid: context.session.uid,
          ),
        );
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, this.hint});

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            Gap.h12,
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (hint != null) ...[
              Gap.h8,
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
