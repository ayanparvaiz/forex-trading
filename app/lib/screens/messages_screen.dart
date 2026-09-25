import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/firestore_community_repository.dart';
import '../data/room_repository.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bits.dart';
import '../widgets/mute_sheet.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'room_screen.dart';
import 'search_screen.dart';

/// Your conversations, most recent first, under the Global room.
///
/// Everyone you are connected with is here — accepting a request opens the
/// conversation — ordered by the last thing said. Global is pinned above
/// them all, for everyone, joined or not.
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

  /// Wakes the list when the soonest "typing…" runs out, so a row does not
  /// keep saying it after the other person has stopped.
  Timer? _typingExpiry;

  void _scheduleTypingExpiry(ChatInbox inbox) {
    final now = DateTime.now();
    Duration? soonest;
    for (final t in inbox.threads) {
      final other = t.otherUid(inbox.uid);
      if (!isTyping(t, other, now)) continue;
      final left = typingWindow - now.difference(t.typing[other]!);
      if (soonest == null || left < soonest) soonest = left;
    }
    _typingExpiry?.cancel();
    if (soonest == null) return;
    _typingExpiry = Timer(soonest + const Duration(milliseconds: 150), () {
      if (mounted) setState(() {});
    });
  }

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
    _typingExpiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final inbox = InboxScope.of(context);
    if (inbox != null) _scheduleTypingExpiry(inbox);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.messages),
        actions: [
          IconButton(
            onPressed: () => openSearch(context),
            icon: const Icon(Icons.search_rounded),
            tooltip: s.search,
          ),
          Gap.w4,
        ],
      ),
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
        final ChatInbox inbox => _List(inbox: inbox, s: s),
      },
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.inbox, required this.s});

  final ChatInbox inbox;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final threads = inbox.threads;
    final pinned = inbox.rooms != null;
    // With no chats yet, Global still sits on top and the hint goes under it.
    final Widget? empty = threads.isNotEmpty
        ? null
        : inbox.error != null
        ? _Empty(icon: Icons.cloud_off_outlined, title: s.couldNotLoad)
        : _Empty(
            icon: Icons.chat_bubble_outline_rounded,
            title: s.noChatsTitle,
            hint: s.noChatsHint,
          );
    final head = pinned ? 1 : 0;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      itemCount: head + (empty == null ? threads.length : 1),
      itemBuilder: (context, i) {
        if (pinned && i == 0) return _GlobalRow(inbox: inbox, s: s);
        if (empty != null) {
          return Padding(padding: const EdgeInsets.only(top: 48), child: empty);
        }
        return _ThreadRow(thread: threads[i - head], inbox: inbox, s: s);
      },
    );
  }
}

/// The Global room, pinned above every chat.
///
/// Before joining it says "Join now" and counts nothing. Joined, it reads
/// like any chat: the last thing said and who said it, the time, and what
/// you have not read — quieter when muted.
class _GlobalRow extends StatelessWidget {
  const _GlobalRow({required this.inbox, required this.s});

  final ChatInbox inbox;
  final Strings s;

  static const _id = RoomRepository.globalId;

  @override
  Widget build(BuildContext context) {
    final me = inbox.uid;
    final now = DateTime.now();
    final room = inbox.global;
    final joined = inbox.joinedGlobal;
    final prefs = inbox.prefsFor(_id);
    final muted = joined && prefs.mutedAt(now);
    final unread = inbox.globalUnread;
    final loud = unread > 0 && !muted;
    final last = room?.lastMessage;

    // What the second line says, and whether it is a note rather than words.
    final (String line, bool note) = switch (last) {
      _ when !inbox.globalKnown => ('', false),
      _ when !joined => (s.joinNow, false),
      null => (s.members(room?.memberCount ?? 0), true),
      _ when prefs.clearedBy(room!.updatedAt) => (
        s.members(room.memberCount),
        true,
      ),
      _ when prefs.hidden.contains(last.id) => (s.youDeletedMessage, true),
      // Someone you have blocked: their words stay out of your inbox too.
      _ when inbox.isBlocked(last.senderUid) => (
        s.members(room.memberCount),
        true,
      ),
      ChatPreview(unsent: true) => (
        last.senderUid == me ? s.youUnsent : s.theyUnsent,
        true,
      ),
      final p => (
        (p.senderUid == me ? s.youPrefix : '${p.senderName ?? ''}: ') +
            s.messagePreview(p.text, p.attachmentType),
        false,
      ),
    };
    // The time of the last message, when there is one to show.
    final DateTime? time =
        joined &&
            room != null &&
            last != null &&
            !prefs.clearedBy(room.updatedAt)
        ? room.updatedAt
        : null;

    return InkWell(
      onTap: () => openGlobalChat(context),
      onLongPress: inbox.globalKnown ? () => _actions(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 10),
        child: Row(
          children: [
            const RoomAvatar(size: 52),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.globalChat,
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
                      if (time != null)
                        Text(
                          s.threadTime(time, now),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: loud
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: loud
                                ? AppColors.profit
                                : AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: note
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontWeight: !joined || unread > 0
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: !joined
                                ? AppColors.brand
                                : unread > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (muted) ...[
                        Gap.w8,
                        const Icon(
                          Icons.notifications_off,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ],
                      Gap.w8,
                      if (unread > 0)
                        Container(
                          constraints: const BoxConstraints(minWidth: 21),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: muted
                                ? AppColors.textMuted
                                : AppColors.profit,
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
                        )
                      else
                        // Pinned, as WhatsApp marks a pinned chat.
                        Transform.rotate(
                          angle: 0.6,
                          child: const Icon(
                            Icons.push_pin,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                        ),
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

  Future<void> _actions(BuildContext context) async {
    final now = DateTime.now();
    final joined = inbox.joinedGlobal;
    final prefs = inbox.prefsFor(_id);
    final muted = prefs.mutedAt(now);
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
            if (joined)
              ListTile(
                leading: Icon(
                  muted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: Text(muted ? s.unmute : s.muteNotifications),
                subtitle: muted
                    ? Text(s.mutedUntil(prefs.mutedUntil!, now))
                    : null,
                onTap: () => Navigator.of(sheet).pop(muted ? 'unmute' : 'mute'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(s.deleteChat),
              onTap: () => Navigator.of(sheet).pop('clear'),
            ),
            if (joined)
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.loss,
                ),
                title: Text(
                  s.leave,
                  style: const TextStyle(color: AppColors.loss),
                ),
                onTap: () => Navigator.of(sheet).pop('leave'),
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.group_add_outlined,
                  color: AppColors.brand,
                ),
                title: Text(
                  s.join,
                  style: const TextStyle(color: AppColors.brand),
                ),
                onTap: () => Navigator.of(sheet).pop('join'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'mute':
        await muteChat(context, inbox, _id);
      case 'unmute':
        await unmuteChat(inbox, _id);
      case 'clear':
        await confirmClearRoom(context, _id);
      case 'join':
        await joinRoom(context, _id);
      case 'leave':
        await confirmLeaveRoom(context, _id);
    }
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
    // Typing replaces the preview, as in WhatsApp: it is the newer news.
    final typing =
        isTyping(thread, otherUid, now) && !inbox.isBlocked(otherUid);

    // Deleted for me: the preview says so rather than showing it anyway.
    final prefs = inbox.prefsFor(thread.id);
    final hiddenLast = last != null && prefs.hidden.contains(last.id);
    // Muted: still listed and still counted in the row, just quieter — grey
    // where it would be green, as WhatsApp does.
    final muted = prefs.mutedAt(now);
    final loud = unread > 0 && !muted;
    final preview = switch (last) {
      null => s.sayHi,
      _ when hiddenLast => s.youDeletedMessage,
      ChatPreview(unsent: true) => mine ? s.youUnsent : s.theyUnsent,
      final ChatPreview p =>
        (mine ? s.youPrefix : '') + s.messagePreview(p.text, p.attachmentType),
    };

    return InkWell(
      onTap: () => openChat(
        context,
        chatId: thread.id,
        otherUid: otherUid,
        otherUsername: otherUsername,
      ),
      onLongPress: () => _actions(
        context,
        otherUsername,
        partner?.name.isNotEmpty == true ? partner!.name : '@$otherUsername',
        unread > 0,
        prefs,
      ),
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
                          fontWeight: loud ? FontWeight.w700 : FontWeight.w400,
                          color: loud ? AppColors.profit : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (!typing &&
                          mine &&
                          last != null &&
                          !last.unsent &&
                          !hiddenLast) ...[
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
                        child: typing
                            ? Text(
                                s.typing,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.profit,
                                ),
                              )
                            : Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle:
                                      last == null || last.unsent || hiddenLast
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
                      if (muted) ...[
                        Gap.w8,
                        const Icon(
                          Icons.notifications_off,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ],
                      if (unread > 0) ...[
                        Gap.w8,
                        Container(
                          constraints: const BoxConstraints(minWidth: 21),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: muted
                                ? AppColors.textMuted
                                : AppColors.profit,
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
    String otherName,
    bool isUnread,
    ChatPrefs prefs,
  ) async {
    final now = DateTime.now();
    final muted = prefs.mutedAt(now);
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
              leading: Icon(
                muted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(muted ? s.unmute : s.muteNotifications),
              subtitle: muted
                  ? Text(s.mutedUntil(prefs.mutedUntil!, now))
                  : null,
              onTap: () => Navigator.of(sheet).pop(muted ? 'unmute' : 'mute'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(s.viewProfile),
              onTap: () => Navigator.of(sheet).pop('profile'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.loss,
              ),
              title: Text(
                s.deleteChat,
                style: const TextStyle(color: AppColors.loss),
              ),
              onTap: () => Navigator.of(sheet).pop('delete'),
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
      case 'mute':
        await muteChat(context, inbox, thread.id);
      case 'unmute':
        await unmuteChat(inbox, thread.id);
      case 'delete':
        await _delete(context, otherName);
    }
  }

  /// "Delete chat", from my side only. The other person keeps everything,
  /// and the chat comes back here the next time either of us writes.
  Future<void> _delete(BuildContext context, String otherName) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.elevated,
        title: Text(s.deleteChatTitle),
        content: Text(s.deleteChatBody(otherName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.loss),
            child: Text(s.deleteChat),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await inbox.repository.clearChat(thread.id, inbox.uid);
      messenger.showSnackBar(SnackBar(content: Text(s.chatDeleted)));
    } catch (e) {
      debugPrint('delete chat failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotDeleteChat)));
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
