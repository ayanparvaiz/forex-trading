import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/firestore_community_repository.dart';
import '../data/push_notifier.dart';
import '../data/room_repository.dart';
import '../data/safety_repository.dart';
import '../data/session_controller.dart';
import '../models/chat.dart';
import '../models/community.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/community_badge.dart';
import '../widgets/conversation_view.dart';
import '../widgets/mute_sheet.dart';
import '../widgets/report_sheet.dart';
import 'community_profile_screen.dart';
import 'post_screen.dart';
import 'profile_screen.dart';

/// Opens the Global room.
Future<void> openGlobalChat(BuildContext context) =>
    openRoom(context, RoomRepository.globalId);

/// Opens room [roomId]: Global, or a community's.
Future<void> openRoom(BuildContext context, String roomId) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => RoomScreen(roomId: roomId)));

/// A room — the Global chat, for everyone, or a community's, for its members.
///
/// Anyone can open Global and read. Joining is what lets you write, and what
/// brings unread counts and banners; leaving ends both. A community's room
/// comes with the community: joined with it, left with it, and read only by
/// its members. The messages behave exactly as in a chat —
/// [ConversationView] — with each run of someone's messages headed by their
/// name.
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
    final m = inbox?.membershipOf(widget.roomId);
    final room = inbox?.room(widget.roomId);
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
    if (_busy) return;
    setState(() => _busy = true);
    await joinRoom(context, widget.roomId);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _menu(String action) async {
    final inbox = _inbox;
    if (inbox == null) return;
    switch (action) {
      case 'mute':
        await muteChat(context, inbox, widget.roomId);
      case 'unmute':
        await unmuteChat(inbox, widget.roomId);
      case 'clear':
        await confirmClearRoom(context, widget.roomId);
      case 'join':
        await _join();
      case 'leave':
        await confirmLeaveRoom(context, widget.roomId);
      case 'community':
        _openCommunity();
    }
  }

  /// A community's room leads to the community, where it is joined and left.
  void _openCommunity() {
    final id = Community.ofRoom(widget.roomId);
    if (id != null) openCommunity(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final inbox = InboxScope.of(context);
    final now = DateTime.now();
    final room = inbox?.room(widget.roomId);
    final joined = inbox?.joinedRoom(widget.roomId) ?? false;
    final known = inbox?.roomKnown(widget.roomId) ?? false;
    final ofCommunity = Community.ofRoom(widget.roomId) != null;
    final prefs = inbox?.prefsFor(widget.roomId) ?? ChatPrefs.none;
    final muted = joined && prefs.mutedAt(now);
    final source = _source;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: ofCommunity ? _openCommunity : null,
          child: Row(
            children: [
              RoomPicture(
                room: widget.roomId,
                name: room?.name ?? '',
                size: 38,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            roomTitle(s, widget.roomId, room?.name ?? ''),
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
                      room != null
                          ? s.members(room.memberCount)
                          : ofCommunity
                          ? s.membersOnly
                          : s.globalAbout,
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
                if (ofCommunity)
                  PopupMenuItem(
                    value: 'community',
                    child: Row(
                      children: [
                        const Icon(Icons.groups_2_outlined, size: 19),
                        Gap.w12,
                        Text(s.viewCommunity),
                      ],
                    ),
                  )
                else
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
              emptyText: ofCommunity ? s.communityChatEmpty : s.globalEmpty,
              bottom: known && !joined && !ofCommunity
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
              onOpenPost: (id) => openPost(context, id),
              // Tapping a name, or a rank someone shared, opens who it was.
              onOpenSender: (m) {
                final username = m.senderUid == _me
                    ? context.session.profile?.username
                    : m.senderUsername;
                if (username == null || username.isEmpty) return;
                openProfile(
                  context,
                  username,
                  buildCommunityRepository(
                    context.session.language,
                    viewerUid: context.session.uid,
                  ),
                );
              },
            ),
    );
  }
}

/// Joins the room, and says so.
Future<void> joinRoom(BuildContext context, String roomId) async {
  final inbox = InboxScope.read(context);
  final rooms = inbox?.rooms;
  if (inbox == null || rooms == null) return;
  final s = context.s;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await rooms.join(roomId, inbox.uid);
    messenger.showSnackBar(SnackBar(content: Text(s.joinedGlobal)));
  } catch (e) {
    debugPrint('join failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotJoin)));
  }
}

/// Leaves the room, once asked whether you are sure.
Future<void> confirmLeaveRoom(BuildContext context, String roomId) async {
  final inbox = InboxScope.read(context);
  final rooms = inbox?.rooms;
  if (inbox == null || rooms == null) return;
  final s = context.s;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await _confirm(
    context,
    title: s.leaveGlobalTitle,
    body: s.leaveGlobalBody,
    action: s.leave,
  );
  if (!ok) return;
  try {
    await rooms.leave(roomId, inbox.uid);
    messenger.showSnackBar(SnackBar(content: Text(s.leftGlobal)));
  } catch (e) {
    debugPrint('leave failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotJoin)));
  }
}

/// "Delete chat" for a room, once asked: what I have seen goes from my side
/// only, and my read mark moves so nothing counts as unread.
Future<void> confirmClearRoom(BuildContext context, String roomId) async {
  final inbox = InboxScope.read(context);
  if (inbox == null) return;
  final s = context.s;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await _confirm(
    context,
    title: s.deleteChatTitle,
    body: s.deleteRoomBody,
    action: s.deleteChat,
  );
  if (!ok) return;
  try {
    await inbox.repository.clearChat(roomId, inbox.uid, countsUnread: false);
    if (inbox.joinedRoom(roomId)) {
      await inbox.rooms?.markRead(roomId, inbox.uid);
    }
    messenger.showSnackBar(SnackBar(content: Text(s.chatDeleted)));
  } catch (e) {
    debugPrint('clear room failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotDeleteChat)));
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final s = context.s;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.elevated,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.loss),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
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
    // Once the server has it, the members' phones are told.
    return rooms
        .send(
          roomId: roomId,
          me: me,
          name: p.displayName,
          username: p.username,
          text: text,
          replyTo: replyTo,
        )
        .then((id) => pushNotifier?.room(roomId, id));
  }

  @override
  Future<void> unsend(ChatMessage m, {required bool isLatest}) =>
      rooms.unsend(roomId: roomId, me: me, message: m, isLatest: isLatest);
}
