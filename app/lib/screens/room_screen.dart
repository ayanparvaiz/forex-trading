import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/room_repository.dart';
import '../data/safety_repository.dart';
import '../data/session_controller.dart';
import '../models/chat.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bits.dart';
import '../widgets/conversation_view.dart';
import '../widgets/mute_sheet.dart';
import '../widgets/report_sheet.dart';

/// Opens the Global room.
Future<void> openGlobalChat(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => const RoomScreen(roomId: RoomRepository.globalId),
  ),
);

/// A room — the Global chat, for everyone.
///
/// Anyone can open it and read. Joining is what lets you write, and what
/// brings unread counts and banners; leaving ends both. The messages behave
/// exactly as in a chat — [ConversationView] — with each run of someone's
/// messages headed by their name.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  RoomRepository? _rooms;
  ChatInbox? _inbox;
  late String _me;
  _RoomSource? _source;

  bool _started = false;
  bool _markingRead = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _rooms = buildRoomRepository();
      _inbox = InboxScope.read(context);
      final session = context.session;
      _me = session.uid ?? '';
      _inbox?.openChatId = widget.roomId;
      // The room moves on its own listener, not this screen's: whenever it
      // does, see whether there is something to mark read.
      _inbox?.addListener(_maybeMarkRead);
      final rooms = _rooms;
      if (rooms != null) {
        _source = _RoomSource(
          rooms: rooms,
          roomId: widget.roomId,
          me: _me,
          profile: () => session.profile,
        );
      }
    }
    // Also runs when a screen pushed over this one is popped.
    _maybeMarkRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inbox?.removeListener(_maybeMarkRead);
    if (_inbox?.openChatId == widget.roomId) _inbox?.openChatId = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeMarkRead();
  }

  /// Moves my read mark when a member is actually looking: the app in
  /// front, this screen on top, and something new since the mark.
  void _maybeMarkRead() {
    final inbox = _inbox;
    final rooms = _rooms;
    final m = inbox?.globalMembership;
    final room = inbox?.global;
    if (!mounted || rooms == null || m == null || room == null) return;
    if (_markingRead || !m.behind(room)) return;
    if (!(inbox?.isForeground ?? true)) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _markingRead = true;
    rooms
        .markRead(widget.roomId, _me)
        .catchError((Object e) => debugPrint('room read mark failed: $e'))
        .whenComplete(() => _markingRead = false);
  }

  Future<void> _join() async {
    final rooms = _rooms;
    if (rooms == null || _busy) return;
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await rooms.join(widget.roomId, _me);
      messenger.showSnackBar(SnackBar(content: Text(s.joinedGlobal)));
    } catch (e) {
      debugPrint('join failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotJoin)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final rooms = _rooms;
    if (rooms == null) return;
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.elevated,
        title: Text(s.leaveGlobalTitle),
        content: Text(s.leaveGlobalBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.loss),
            child: Text(s.leave),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await rooms.leave(widget.roomId, _me);
      messenger.showSnackBar(SnackBar(content: Text(s.leftGlobal)));
    } catch (e) {
      debugPrint('leave failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotJoin)));
    }
  }

  Future<void> _menu(String action) async {
    final inbox = _inbox;
    if (inbox == null) return;
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case 'mute':
        final until = await pickMuteUntil(context);
        if (until == null) return;
        await inbox.repository
            .mute(widget.roomId, _me, until)
            .catchError((Object e) => debugPrint('mute failed: $e'));
        messenger.showSnackBar(
          SnackBar(content: Text(s.mutedUntil(until, DateTime.now()))),
        );
      case 'unmute':
        await inbox.repository
            .unmute(widget.roomId, _me)
            .catchError((Object e) => debugPrint('unmute failed: $e'));
      case 'clear':
        await _clear();
      case 'join':
        await _join();
      case 'leave':
        await _leave();
    }
  }

  /// "Delete chat", from my side only; everyone else keeps everything.
  Future<void> _clear() async {
    final inbox = _inbox;
    if (inbox == null) return;
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.elevated,
        title: Text(s.deleteChatTitle),
        content: Text(s.deleteRoomBody),
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
      await clearRoomForMe(inbox, widget.roomId, _me);
      messenger.showSnackBar(SnackBar(content: Text(s.chatDeleted)));
    } catch (e) {
      debugPrint('clear room failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotDeleteChat)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final inbox = InboxScope.of(context);
    final now = DateTime.now();
    final room = inbox?.global;
    final joined = inbox?.joinedGlobal ?? false;
    final known = inbox?.globalKnown ?? false;
    final prefs = inbox?.prefsFor(widget.roomId) ?? ChatPrefs.none;
    final muted = joined && prefs.mutedAt(now);
    final source = _source;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const RoomAvatar(size: 38),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          s.globalChat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (muted)
                        const Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Icon(
                            Icons.notifications_off,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    room == null ? s.globalAbout : s.members(room.memberCount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (known)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: AppColors.elevated,
              onSelected: _menu,
              itemBuilder: (_) => [
                if (joined)
                  PopupMenuItem(
                    value: muted ? 'unmute' : 'mute',
                    child: MuteMenuRow(s: s, prefs: prefs, now: now),
                  ),
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 19),
                      Gap.w12,
                      Text(s.deleteChat),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: joined ? 'leave' : 'join',
                  child: Row(
                    children: [
                      Icon(
                        joined
                            ? Icons.logout_rounded
                            : Icons.group_add_outlined,
                        size: 19,
                        color: joined ? AppColors.loss : AppColors.brand,
                      ),
                      Gap.w12,
                      Text(
                        joined ? s.leave : s.join,
                        style: TextStyle(
                          color: joined ? AppColors.loss : AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: source == null
          ? Center(child: Text(s.messagingNeedsServer))
          : ConversationView(
              source: source,
              me: _me,
              canSend: joined,
              nameOf: (uid, m) {
                if (uid == _me) return s.you;
                final name = m?.senderName ?? '';
                return name.isNotEmpty ? name : '…';
              },
              emptyText: s.globalEmpty,
              bottom: known && !joined
                  ? ComposerNote(
                      text: s.joinToWrite,
                      action: _busy ? null : s.join,
                      onAction: _join,
                    )
                  : null,
              showSenderNames: true,
              // Blocking cannot keep anyone out of a room, so their
              // messages are just not shown to you.
              hiddenSenders: {for (final b in inbox?.blocked ?? []) b.uid},
              // A room has no delivered or read marks — just on its way, or
              // there.
              statusOf: (m) =>
                  m.pending ? MessageStatus.pending : MessageStatus.sent,
              extraActions: (m) => [
                if (m.senderUid != _me && inbox?.safety != null)
                  MessageAction(
                    icon: Icons.flag_outlined,
                    label: s.report,
                    danger: true,
                    onSelected: () => showReportSheet(
                      context,
                      ReportTarget.message(
                        targetUid: m.senderUid,
                        targetUsername: m.senderUsername ?? '',
                        chatId: widget.roomId,
                        messageId: m.id,
                        quote: m.text,
                      ),
                    ),
                  ),
              ],
              onMessages: (_) => _maybeMarkRead(),
            ),
    );
  }
}

/// "Delete chat" for a room: what I have seen goes from my side, and my
/// read mark moves so nothing counts as unread.
Future<void> clearRoomForMe(ChatInbox inbox, String roomId, String me) async {
  await inbox.repository.clearChat(roomId, me, countsUnread: false);
  if (inbox.joinedGlobal) await inbox.rooms?.markRead(roomId, me);
}

/// The room, as [ConversationView] reads it.
class _RoomSource implements MessageSource {
  _RoomSource({
    required this.rooms,
    required this.roomId,
    required this.me,
    required this.profile,
  });

  final RoomRepository rooms;
  final String roomId;
  final String me;

  /// Who I am right now — the name a message goes out under.
  final UserProfile? Function() profile;

  @override
  String get prefsId => roomId;

  @override
  int get pageSize => RoomRepository.pageSize;

  @override
  Stream<List<ChatMessage>> watchLatest() => rooms.watchLatest(roomId);

  @override
  Future<List<ChatMessage>> olderThan(Object cursor) =>
      rooms.olderThan(roomId, cursor);

  @override
  Future<ChatMessage?> message(String id) => rooms.message(roomId, id);

  @override
  Future<void> send(String text, {ReplyRef? replyTo}) {
    final p = profile();
    if (p == null) return Future.error(StateError('signed out'));
    return rooms.send(
      roomId: roomId,
      me: me,
      name: p.displayName,
      username: p.username,
      text: text,
      replyTo: replyTo,
    );
  }

  @override
  Future<void> unsend(ChatMessage m, {required bool isLatest}) =>
      rooms.unsend(roomId: roomId, me: me, message: m, isLatest: isLatest);
}
