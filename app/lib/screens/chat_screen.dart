import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_inbox.dart';
import '../data/chat_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bits.dart';
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

/// One conversation.
///
/// Newest at the bottom, the way every chat app reads. The list is built in
/// reverse so the bottom is where it starts and where new messages land, and
/// scrolling up past the loaded messages fetches the page before them.
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

  ChatThread? _thread;
  List<ChatMessage> _messages = const [];
  bool _firstPageIn = false;
  bool _loadingOlder = false;
  bool _noMoreOlder = false;

  /// Null until checked. Sending needs a connection; reading does not.
  bool? _connected;
  ChatPartner? _partner;

  StreamSubscription<ChatThread?>? _threadSub;
  StreamSubscription<List<ChatMessage>>? _latestSub;

  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _showJump = false;
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
    _scroll.addListener(_onScroll);
    _input.addListener(_onInputChanged);
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

      _threadSub = repo.watchThread(widget.chatId).listen((t) {
        if (!mounted) return;
        setState(() => _thread = t);
        _maybeMarkRead();
      });
      _latestSub = repo.watchLatest(widget.chatId).listen((latest) {
        if (!mounted) return;
        setState(() {
          // A first page shorter than a page is the whole conversation.
          if (!_firstPageIn && latest.length < ChatRepository.pageSize) {
            _noMoreOlder = true;
          }
          _firstPageIn = true;
          _messages = mergeMessages(_messages, latest);
        });
        _maybeMarkRead();
      }, onError: (Object e) => debugPrint('messages stream failed: $e'));

      final connected = await repo.isConnected(widget.chatId);
      _partner ??= (await repo.partners([widget.otherUid]))[widget.otherUid];
      if (mounted) setState(() => _connected = connected);
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

  void _onScroll() {
    final pos = _scroll.position;
    // Reversed list: the far end is the top, where older messages are.
    if (pos.pixels > pos.maxScrollExtent - 300) _loadOlder();
    final jump = pos.pixels > 500;
    if (jump != _showJump) setState(() => _showJump = jump);
  }

  Future<void> _loadOlder() async {
    final repo = _repo;
    if (repo == null || _loadingOlder || _noMoreOlder || !_firstPageIn) return;
    // The oldest message the server has confirmed. A pending one has no
    // server time yet, so it cannot say where the previous page ends.
    Object? cursor;
    for (final m in _messages.reversed) {
      if (!m.pending && m.cursor != null) {
        cursor = m.cursor;
        break;
      }
    }
    if (cursor == null) return;

    setState(() => _loadingOlder = true);
    try {
      final older = await repo.olderThan(widget.chatId, cursor);
      if (!mounted) return;
      setState(() {
        _messages = mergeMessages(_messages, older);
        if (older.length < ChatRepository.pageSize) _noMoreOlder = true;
      });
    } catch (e) {
      debugPrint('older messages failed: $e');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  /// Stamps my typing mark while the box has text — at most once every
  /// [typingRefresh], however fast the keys go — and clears it when the box
  /// is emptied.
  void _onInputChanged() {
    final repo = _repo;
    if (repo == null || _connected != true) return;

    final now = DateTime.now();
    if (_input.text.trim().isNotEmpty) {
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
    }
    // A block ends the connection, and an unblock does not restore it; either
    // way, whether this conversation can send has to be asked again.
    if (action != 'profile' && mounted) {
      final connected = await _repo?.isConnected(widget.chatId);
      if (mounted) setState(() => _connected = connected ?? false);
    }
  }

  void _send() {
    final repo = _repo;
    final text = _input.text.trim();
    if (repo == null || text.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    // The send itself removes the typing mark, in the same batch; forget it
    // here first so clearing the box does not write a second removal.
    _typingSentAt = null;
    _input.clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);

    // Not awaited: the message shows from the local cache at once, marked
    // pending, and becomes a tick when the server has it.
    repo
        .send(
          chatId: widget.chatId,
          me: _me,
          other: widget.otherUid,
          text: text,
        )
        .catchError((Object e) {
          debugPrint('send failed: $e');
          messenger.showSnackBar(SnackBar(content: Text(s.messageNotSent)));
          if (_input.text.isEmpty) _input.text = text;
        });
  }

  Future<void> _showActions(ChatMessage m) async {
    final s = context.s;
    final mine = m.senderUid == _me;
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
              leading: const Icon(Icons.copy_rounded),
              title: Text(s.copy),
              onTap: () => Navigator.of(sheet).pop('copy'),
            ),
            if (mine && !m.pending)
              ListTile(
                leading: const Icon(Icons.undo_rounded, color: AppColors.loss),
                title: Text(
                  s.unsend,
                  style: const TextStyle(color: AppColors.loss),
                ),
                onTap: () => Navigator.of(sheet).pop('unsend'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.copied)));
    } else if (action == 'unsend') {
      await _confirmUnsend(m);
    }
  }

  Future<void> _confirmUnsend(ChatMessage m) async {
    final s = context.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.elevated,
        title: Text(s.unsendTitle),
        content: Text(s.unsendBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.loss),
            child: Text(s.unsend),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo
        ?.unsend(
          chatId: widget.chatId,
          me: _me,
          messageId: m.id,
          isLatest: _thread?.lastMessage?.id == m.id,
        )
        .catchError((Object e) => debugPrint('unsend failed: $e'));
  }

  @override
  void dispose() {
    _clearTyping();
    _typingExpiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_inbox?.openChatId == widget.chatId) _inbox?.openChatId = null;
    _threadSub?.cancel();
    _latestSub?.cancel();
    _clock?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
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
                    Text(
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
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _messageList(s, now, typing),
                if (_showJump)
                  Positioned(
                    right: Gap.md,
                    bottom: Gap.md,
                    child: FloatingActionButton.small(
                      heroTag: null,
                      backgroundColor: AppColors.elevated,
                      foregroundColor: AppColors.textPrimary,
                      onPressed: () => _scroll.animateTo(
                        0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
              ],
            ),
          ),
          if (blockedByMe)
            _NotConnected(
              text: s.blockedChatNote,
              action: s.unblock,
              onAction: () => _menu('unblock'),
            )
          else if (_connected == false)
            _NotConnected(text: s.notConnectedToMessage)
          else
            _Composer(
              controller: _input,
              hint: s.typeMessage,
              enabled: _connected == true,
              onSend: _send,
            ),
        ],
      ),
    );
  }

  Widget _messageList(Strings s, DateTime now, bool typing) {
    if (!_firstPageIn) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.brand,
        ),
      );
    }
    if (_messages.isEmpty && !typing) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(Gap.xl),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: Radii.tile,
          ),
          child: Text(
            s.sayHi,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final items = _layout(_messages);
    final thread = _thread;

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
      itemCount: items.length + (_noMoreOlder ? 0 : 1) + (typing ? 1 : 0),
      itemBuilder: (context, index) {
        // Index 0 is the bottom of a reversed list, which is where the
        // typing bubble belongs — under the newest message.
        if (typing && index == 0) return const TypingBubble();
        final i = typing ? index - 1 : index;
        if (i == items.length) {
          return Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Center(
              child: _loadingOlder
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMuted,
                      ),
                    )
                  : Text(
                      s.loadingOlder,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
          );
        }
        final item = items[i];
        if (item.day != null) {
          return _DaySeparator(label: s.dayLabel(item.day!, now));
        }
        final m = item.message!;
        final mine = m.senderUid == _me;
        return _Bubble(
          message: m,
          mine: mine,
          tail: item.groupEnd,
          time: s.clock(m.sentAt),
          unsentLabel: mine ? s.youUnsent : s.theyUnsent,
          status: mine && thread != null ? statusOf(m, thread, _me) : null,
          onLongPress: m.unsent ? null : () => _showActions(m),
        );
      },
    );
  }

  /// Messages, newest first, with a day separator above each day and each
  /// run of messages from one person grouped: only the last message of a run
  /// gets a tail and full spacing, as in every chat app.
  List<_Item> _layout(List<ChatMessage> messages) {
    final out = <_Item>[];
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      final newer = i > 0 ? messages[i - 1] : null;
      final older = i + 1 < messages.length ? messages[i + 1] : null;

      final groupEnd =
          newer == null ||
          newer.senderUid != m.senderUid ||
          dayOf(newer.sentAt) != dayOf(m.sentAt) ||
          newer.sentAt.difference(m.sentAt) > const Duration(minutes: 5);
      out.add(_Item.message(m, groupEnd: groupEnd));

      // In a reversed list, what comes next is drawn above — so the
      // separator goes after the oldest message of each day.
      if ((older == null && _noMoreOlder) ||
          (older != null && dayOf(older.sentAt) != dayOf(m.sentAt))) {
        out.add(_Item.day(dayOf(m.sentAt)));
      }
    }
    return out;
  }
}

class _Item {
  _Item.message(this.message, {required this.groupEnd}) : day = null;
  _Item.day(this.day) : message = null, groupEnd = false;

  final ChatMessage? message;
  final DateTime? day;
  final bool groupEnd;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: Radii.field,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.tail,
    required this.time,
    required this.unsentLabel,
    required this.status,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final bool tail;
  final String time;
  final String unsentLabel;
  final MessageStatus? status;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    const r = Radius.circular(12);
    const flat = Radius.circular(3);

    // Time and ticks sit inside the bubble at the bottom right. The text
    // carries an invisible gap the same width at its end, so a short last
    // line leaves room for them and a long one pushes them onto their own.
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 10.5,
            color: mine
                ? Colors.white.withValues(alpha: 0.62)
                : AppColors.textMuted,
          ),
        ),
        if (status != null) ...[
          const SizedBox(width: 3),
          MessageTicks(status: status!),
        ],
      ],
    );
    final metaWidth = status != null ? 78.0 : 58.0;

    final Widget body = message.unsent
        ? Text.rich(
            TextSpan(
              children: [
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(right: 5),
                    child: Icon(
                      Icons.block,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                TextSpan(text: unsentLabel),
                WidgetSpan(child: SizedBox(width: metaWidth - 20)),
              ],
            ),
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.textMuted,
            ),
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(text: message.text),
                WidgetSpan(child: SizedBox(width: metaWidth)),
              ],
            ),
            style: const TextStyle(
              fontSize: 15,
              height: 1.35,
              color: AppColors.textPrimary,
            ),
          );

    return Padding(
      padding: EdgeInsets.only(top: tail ? 6 : 2),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 9, 7),
              decoration: BoxDecoration(
                color: mine ? AppColors.bubbleMine : AppColors.bubbleTheirs,
                borderRadius: BorderRadius.only(
                  topLeft: r,
                  topRight: r,
                  bottomLeft: !mine && tail ? flat : r,
                  bottomRight: mine && tail ? flat : r,
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: body,
                  ),
                  Positioned(right: 0, bottom: 0, child: meta),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, Gap.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                  decoration: InputDecoration(
                    hintText: hint,
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.elevated,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final ready = enabled && controller.text.trim().isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: ready ? AppColors.brand : AppColors.elevated,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: ready ? onSend : null,
                      icon: Icon(
                        Icons.send_rounded,
                        size: 21,
                        color: ready ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                  child: Text(
                    action!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
