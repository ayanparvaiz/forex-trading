import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/chat_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/safety_repository.dart';
import '../data/session_controller.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bits.dart';
import '../widgets/conversation_view.dart';
import '../widgets/mute_sheet.dart';
import '../widgets/report_sheet.dart';
import '../widgets/safety_actions.dart';
import 'profile_screen.dart';

/// Opens the conversation with another trader.
Future<void> openChat(
  BuildContext context, {
  required String chatId,
  required String otherUid,
  required String otherUsername,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatScreen(
        chatId: chatId,
        otherUid: otherUid,
        otherUsername: otherUsername,
      ),
    ),
  );
}

/// One conversation between two people.
///
/// The messages themselves — the list, replying, forwarding, deleting — are
/// [ConversationView], shared with the Global room. What is particular to
/// two people is here: who they are and whether they are around, whether
/// you may still send (connected, not blocked), typing, and the ticks.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherUsername,
  });

  final String chatId;
  final String otherUid;
  final String otherUsername;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  ChatRepository? _repo;
  ChatInbox? _inbox;
  late String _me;

  /// Set once the conversation is known to exist.
  _DirectSource? _source;

  ChatThread? _thread;

  /// The loaded messages, newest first, as the view last reported them —
  /// for deciding whether there is anything to mark read.
  List<ChatMessage> _messages = const [];

  /// Null until checked. Sending needs a connection; reading does not.
  /// Watched, so a block or a disconnect closes the composer at once.
  bool? _connected;
  ChatPartner? _partner;

  /// The other person has blocked me — asked only once the connection is
  /// gone, since a block always ends it.
  bool _blockedMe = false;

  StreamSubscription<ChatThread?>? _threadSub;
  StreamSubscription<bool>? _connectedSub;
  bool _markingRead = false;

  /// Presence text is relative to now, so it has to move on its own:
  /// "active now" becomes "active 3m ago" without any new data arriving.
  Timer? _clock;

  /// When I last stamped my typing mark, or null if I have none showing.
  DateTime? _typingSentAt;

  /// Wakes the screen when the other person's typing mark runs out, so
  /// "typing…" goes away even if nothing else changes.
  Timer? _typingExpiry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also runs when a screen pushed over this one is popped, because the
    // route's "current" status is a dependency — which is exactly when a
    // conversation you have come back to should be marked read.
    if (!_started) {
      _started = true;
      _repo = buildChatRepository();
      _inbox = InboxScope.read(context);
      _me = context.session.uid ?? '';
      _inbox?.openChatId = widget.chatId;
      _partner = _inbox?.partner(widget.otherUid);
      _open();
    }
    _maybeMarkRead();
  }

  Future<void> _open() async {
    final repo = _repo;
    if (repo == null) return;

    try {
      final exists = await repo.ensureChat(widget.chatId);
      if (!mounted) return;
      if (!exists) {
        setState(() => _connected = false);
        return;
      }

      setState(
        () => _source = _DirectSource(
          repo: repo,
          chatId: widget.chatId,
          me: _me,
          other: widget.otherUid,
        ),
      );
      _threadSub = repo.watchThread(widget.chatId).listen((t) {
        if (!mounted) return;
        setState(() => _thread = t);
        _maybeMarkRead();
      });
      _connectedSub = repo.watchConnected(widget.chatId).listen((
        connected,
      ) async {
        final safety = _inbox?.safety;
        final blockedMe =
            !connected &&
            safety != null &&
            await safety.hasBlockedMe(me: _me, otherUid: widget.otherUid);
        if (!mounted) return;
        if (!connected) _clearTyping();
        setState(() {
          _connected = connected;
          _blockedMe = blockedMe;
        });
      }, onError: (Object e) => debugPrint('connection watch failed: $e'));
      _partner ??= (await repo.partners([widget.otherUid]))[widget.otherUid];
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('open chat failed: $e');
      if (mounted) setState(() => _connected ??= false);
    }
  }

  /// Marks the conversation read when — and only when — someone is actually
  /// looking at it: the app in front, and this screen on top.
  void _maybeMarkRead() {
    final thread = _thread;
    final repo = _repo;
    if (!mounted || thread == null || repo == null || _markingRead) return;
    if (!(_inbox?.isForeground ?? true)) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;

    final myMark = thread.readAt[_me];
    final newestIncoming = _messages
        .where((m) => m.senderUid != _me && !m.pending)
        .firstOrNull;
    final behind =
        newestIncoming != null &&
        (myMark == null || newestIncoming.sentAt.isAfter(myMark));

    if (thread.unreadFor(_me) == 0 && !behind) return;
    _markingRead = true;
    repo
        .markRead(widget.chatId, _me)
        .catchError((Object e) => debugPrint('mark read failed: $e'))
        .whenComplete(() => _markingRead = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeMarkRead();
    } else if (state == AppLifecycleState.paused) {
      _clearTyping();
    }
  }

  /// What I have deleted for myself here, and whether it is muted.
  ChatPrefs get _prefs => _inbox?.prefsFor(widget.chatId) ?? ChatPrefs.none;

  // --- Typing ---------------------------------------------------------------

  /// Stamps my typing mark while the box has text — at most once every
  /// [typingRefresh], however fast the keys go — and clears it when the box
  /// is emptied.
  void _onDraftChanged(String text) {
    final repo = _repo;
    if (repo == null || _connected != true) return;

    final now = DateTime.now();
    if (text.trim().isNotEmpty) {
      final last = _typingSentAt;
      if (last != null && now.difference(last) < typingRefresh) return;
      _typingSentAt = now;
      repo
          .setTyping(widget.chatId, _me)
          .catchError((Object e) => debugPrint('typing mark failed: $e'));
    } else {
      _clearTyping();
    }
  }

  void _clearTyping() {
    final repo = _repo;
    final last = _typingSentAt;
    _typingSentAt = null;
    // Nothing to clear if the mark has already run out on its own.
    if (repo == null ||
        last == null ||
        DateTime.now().difference(last) > typingWindow) {
      return;
    }
    repo
        .clearTyping(widget.chatId, _me)
        .catchError((Object e) => debugPrint('typing clear failed: $e'));
  }

  /// Whether the other person is typing, arranging to redraw when their mark
  /// runs out so the indicator does not outlive it.
  bool _otherTyping(DateTime now) {
    final thread = _thread;
    if (thread == null || !isTyping(thread, widget.otherUid, now)) {
      return false;
    }
    // Someone you have blocked can still touch the shared conversation
    // document, but nothing they do there is shown to you.
    if (_inbox?.isBlocked(widget.otherUid) ?? false) return false;
    final at = thread.typing[widget.otherUid]!;
    final left = typingWindow - now.difference(at);
    _typingExpiry?.cancel();
    _typingExpiry = Timer(left + const Duration(milliseconds: 150), () {
      if (mounted) setState(() {});
    });
    return true;
  }

  Future<void> _menu(String action) async {
    switch (action) {
      case 'mute':
        final repo = _repo;
        final s = context.s;
        final messenger = ScaffoldMessenger.of(context);
        final until = await pickMuteUntil(context);
        if (until == null || repo == null) return;
        await repo
            .mute(widget.chatId, _me, until)
            .catchError((Object e) => debugPrint('mute failed: $e'));
        messenger.showSnackBar(
          SnackBar(content: Text(s.mutedUntil(until, DateTime.now()))),
        );
      case 'unmute':
        await _repo
            ?.unmute(widget.chatId, _me)
            .catchError((Object e) => debugPrint('unmute failed: $e'));
      case 'profile':
        openProfile(
          context,
          widget.otherUsername,
          buildCommunityRepository(
            context.session.language,
            viewerUid: context.session.uid,
          ),
        );
      case 'block':
        await confirmBlock(
          context,
          otherUid: widget.otherUid,
          otherUsername: widget.otherUsername,
        );
      case 'unblock':
        await unblock(
          context,
          otherUid: widget.otherUid,
          otherUsername: widget.otherUsername,
        );
      case 'report':
        await showReportSheet(
          context,
          ReportTarget.user(
            targetUid: widget.otherUid,
            targetUsername: widget.otherUsername,
          ),
        );
    }
    // Nothing to re-check after a block: it ends the connection, which the
    // watch in _open picks up. An unblock does not restore it.
  }

  @override
  void dispose() {
    _clearTyping();
    _typingExpiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_inbox?.openChatId == widget.chatId) _inbox?.openChatId = null;
    _threadSub?.cancel();
    _connectedSub?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  String get _partnerName {
    final name = _partner?.name ?? '';
    return name.isNotEmpty ? name : '@${widget.otherUsername}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final inbox = InboxScope.of(context);
    final last = inbox?.lastActive(widget.otherUid);
    final now = DateTime.now();
    final presence = presenceOf(last, now);
    final typing = _otherTyping(now);
    final blockedByMe = inbox?.isBlocked(widget.otherUid) ?? false;
    final prefs = _prefs;
    final muted = prefs.mutedAt(now);
    final source = _source;
    final thread = _thread;

    final Widget? note = blockedByMe
        ? ComposerNote(
            text: s.blockedChatNote,
            action: s.unblock,
            onAction: () => _menu('unblock'),
          )
        : _connected == false
        ? ComposerNote(
            text: _blockedMe ? s.cantReplyHere : s.notConnectedToMessage,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => openProfile(
            context,
            widget.otherUsername,
            buildCommunityRepository(
              context.session.language,
              viewerUid: context.session.uid,
            ),
          ),
          child: Row(
            children: [
              ChatAvatar(
                avatarId: _partner?.avatarId ?? 1,
                activeNow: presence == Presence.activeNow,
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
                            _partner?.name.isNotEmpty == true
                                ? _partner!.name
                                : '@${widget.otherUsername}',
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
                    if (typing)
                      Text(
                        s.typing,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.profit,
                        ),
                      )
                    else if (presence != Presence.unknown)
                      Text(
                        presence == Presence.activeNow
                            ? s.activeNow
                            : s.activeAgo(last!, now),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: presence == Presence.activeNow
                              ? AppColors.profit
                              : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppColors.elevated,
            onSelected: (action) => _menu(action),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: muted ? 'unmute' : 'mute',
                child: MuteMenuRow(s: s, prefs: prefs, now: now),
              ),
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 19),
                    Gap.w12,
                    Text(s.viewProfile),
                  ],
                ),
              ),
              if (inbox?.safety != null)
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 19),
                      Gap.w12,
                      Text(s.report),
                    ],
                  ),
                ),
              if (inbox?.safety != null)
                PopupMenuItem(
                  value: blockedByMe ? 'unblock' : 'block',
                  child: Row(
                    children: [
                      Icon(
                        Icons.block,
                        size: 19,
                        color: blockedByMe
                            ? AppColors.textPrimary
                            : AppColors.loss,
                      ),
                      Gap.w12,
                      Text(
                        blockedByMe ? s.unblock : s.block,
                        style: TextStyle(
                          color: blockedByMe
                              ? AppColors.textPrimary
                              : AppColors.loss,
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
          ? Column(
              children: [
                Expanded(
                  child: note == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.brand,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                ?note,
              ],
            )
          : ConversationView(
              source: source,
              me: _me,
              canSend: _connected == true && !blockedByMe,
              nameOf: (uid, _) => uid == _me ? s.you : _partnerName,
              emptyText: s.sayHi,
              bottom: note,
              statusOf: (m) => thread == null ? null : statusOf(m, thread, _me),
              typing: typing,
              // Their messages can be reported, quoted exactly as sent.
              extraActions: (m) => [
                if (m.senderUid != _me && inbox?.safety != null)
                  MessageAction(
                    icon: Icons.flag_outlined,
                    label: s.report,
                    danger: true,
                    onSelected: () => showReportSheet(
                      context,
                      ReportTarget.message(
                        targetUid: widget.otherUid,
                        targetUsername: widget.otherUsername,
                        chatId: widget.chatId,
                        messageId: m.id,
                        quote: m.text,
                      ),
                    ),
                  ),
              ],
              onDraftChanged: _onDraftChanged,
              // The send removes the typing mark in the same batch; forget
              // it first so clearing the box does not write a second removal.
              onBeforeSend: () => _typingSentAt = null,
              onMessages: (messages) {
                _messages = messages;
                _maybeMarkRead();
              },
            ),
    );
  }
}

/// A conversation between two people, as [ConversationView] reads it.
class _DirectSource implements MessageSource {
  _DirectSource({
    required this.repo,
    required this.chatId,
    required this.me,
    required this.other,
  });

  final ChatRepository repo;
  final String chatId;
  final String me;
  final String other;

  @override
  String get prefsId => chatId;

  @override
  int get pageSize => ChatRepository.pageSize;

  @override
  Stream<List<ChatMessage>> watchLatest() => repo.watchLatest(chatId);

  @override
  Future<List<ChatMessage>> olderThan(Object cursor) =>
      repo.olderThan(chatId, cursor);

  @override
  Future<ChatMessage?> message(String id) => repo.message(chatId, id);

  @override
  Future<void> send(String text, {ReplyRef? replyTo}) => repo.send(
    chatId: chatId,
    me: me,
    other: other,
    text: text,
    replyTo: replyTo,
  );

  @override
  Future<void> unsend(ChatMessage m, {required bool isLatest}) =>
      repo.unsend(chatId: chatId, me: me, messageId: m.id, isLatest: isLatest);
}
