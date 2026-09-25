import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_inbox.dart';
import '../data/chat_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/safety_repository.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bits.dart';
import '../widgets/forward_sheet.dart';
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
  /// Watched, so a block or a disconnect closes the composer at once.
  bool? _connected;
  ChatPartner? _partner;

  /// The other person has blocked me — asked only once the connection is
  /// gone, since a block always ends it.
  bool _blockedMe = false;

  StreamSubscription<ChatThread?>? _threadSub;
  StreamSubscription<List<ChatMessage>>? _latestSub;
  StreamSubscription<bool>? _connectedSub;

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

  /// The message being replied to, shown above the box until it is sent or
  /// dismissed.
  ChatMessage? _replyTo;
  final _inputFocus = FocusNode();

  /// Originals of replies that are not among the loaded messages, fetched
  /// once each. A key with a null value is one that could not be found.
  final Map<String, ChatMessage?> _quoted = {};
  final Set<String> _fetchingQuoted = {};

  /// Each bubble's key, so tapping a quote can scroll to its original.
  final Map<String, GlobalKey> _bubbleKeys = {};

  /// The message just scrolled to from a quote, lit up for a moment.
  String? _flashId;
  Timer? _flashTimer;

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

  void _onScroll() {
    final pos = _scroll.position;
    // Reversed list: the far end is the top, where older messages are.
    if (pos.pixels > pos.maxScrollExtent - 300) _loadOlder();
    final jump = pos.pixels > 500;
    if (jump != _showJump) setState(() => _showJump = jump);
  }

  /// What I have deleted for myself here.
  ChatPrefs get _prefs => _inbox?.prefsFor(widget.chatId) ?? ChatPrefs.none;

  /// Nothing older to load: the server has no more, or everything older was
  /// deleted with the chat.
  bool get _nothingOlder =>
      _noMoreOlder ||
      (_messages.isNotEmpty && _prefs.clearedBy(_messages.last.sentAt));

  Future<void> _loadOlder() async {
    final repo = _repo;
    if (repo == null || _loadingOlder || _nothingOlder || !_firstPageIn) {
      return;
    }
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

  void _send() {
    final repo = _repo;
    final text = _input.text.trim();
    if (repo == null || text.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    // The send itself removes the typing mark, in the same batch; forget it
    // here first so clearing the box does not write a second removal.
    _typingSentAt = null;
    final reply = _replyTo;
    setState(() => _replyTo = null);
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
          replyTo: reply == null
              ? null
              : ReplyRef(id: reply.id, senderUid: reply.senderUid),
        )
        .catchError((Object e) {
          debugPrint('send failed: $e');
          messenger.showSnackBar(SnackBar(content: Text(s.messageNotSent)));
          if (_input.text.isEmpty) _input.text = text;
          if (mounted && _replyTo == null && reply != null) {
            setState(() => _replyTo = reply);
          }
        });
  }

  // --- Replies ---------------------------------------------------------------

  /// Replying needs what sending needs.
  bool get _canReply =>
      _connected == true && !(_inbox?.isBlocked(widget.otherUid) ?? false);

  void _startReply(ChatMessage m) {
    if (!_canReply || m.unsent) return;
    setState(() => _replyTo = m);
    _inputFocus.requestFocus();
  }

  String _nameOf(String uid, Strings s) {
    if (uid == _me) return s.you;
    final name = _partner?.name ?? '';
    return name.isNotEmpty ? name : '@${widget.otherUsername}';
  }

  /// The message a reply answers: from those loaded, or fetched once.
  ChatMessage? _original(ReplyRef ref) {
    for (final m in _messages) {
      if (m.id == ref.id) return m;
    }
    if (_quoted.containsKey(ref.id)) return _quoted[ref.id];
    if (_fetchingQuoted.add(ref.id)) {
      _repo
          ?.message(widget.chatId, ref.id)
          .then((m) {
            if (mounted) setState(() => _quoted[ref.id] = m);
          })
          .catchError((Object e) {
            debugPrint('quoted message failed: $e');
            if (mounted) setState(() => _quoted[ref.id] = null);
          });
    }
    return null;
  }

  /// The quote inside a reply's bubble. It shows the original as it is now,
  /// so an unsent original reads as unsent here too.
  Widget _quoteFor(ReplyRef ref, Strings s) {
    final original = _original(ref);
    final loading = original == null && !_quoted.containsKey(ref.id);
    final (text, italic) = switch (original) {
      null when loading => ('…', true),
      null => (s.originalMissing, true),
      ChatMessage(unsent: true) => (
        original.senderUid == _me ? s.youUnsent : s.theyUnsent,
        true,
      ),
      final m => (m.text, false),
    };
    return ReplyQuote(
      name: _nameOf(ref.senderUid, s),
      text: text,
      italic: italic,
      accent: quoteAccent(mine: ref.senderUid == _me),
      onTap: original == null ? null : () => _jumpTo(ref.id),
    );
  }

  /// Scrolls to the message [id] and lights it up.
  ///
  /// The list only builds what is near the screen, so a message far up has
  /// no bubble to scroll to yet: this steps upward — loading older pages
  /// when it reaches the top — until the bubble exists, then centres it.
  Future<void> _jumpTo(String id) async {
    for (final m in _messages) {
      // Deleted for me: there is nothing on screen to go to.
      if (m.id == id && !_prefs.shows(m)) return;
    }
    for (var i = 0; i < 60 && mounted; i++) {
      final target = _bubbleKeys[id]?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        if (mounted) _flash(id);
        return;
      }
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.pixels >= pos.maxScrollExtent - 1) {
        if (_loadingOlder) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          continue;
        }
        if (_nothingOlder) return;
        await _loadOlder();
      } else {
        _scroll.jumpTo(
          math.min(
            pos.pixels + pos.viewportDimension * 0.8,
            pos.maxScrollExtent,
          ),
        );
      }
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _flash(String id) {
    _flashTimer?.cancel();
    setState(() => _flashId = id);
    _flashTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

  /// The strip above the box while a reply is being written.
  Widget? _replyBar(Strings s) {
    final r = _replyTo;
    if (r == null) return null;
    return Container(
      margin: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, 0),
      padding: const EdgeInsets.fromLTRB(6, 6, 0, 6),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: Radii.tile,
      ),
      child: Row(
        children: [
          Expanded(
            child: ReplyQuote(
              name: _nameOf(r.senderUid, s),
              text: r.text,
              accent: quoteAccent(mine: r.senderUid == _me),
              maxLines: 1,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _replyTo = null),
            tooltip: s.cancel,
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
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
            if (_canReply && !m.unsent)
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: Text(s.reply),
                onTap: () => Navigator.of(sheet).pop('reply'),
              ),
            if (!m.unsent)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(s.copy),
                onTap: () => Navigator.of(sheet).pop('copy'),
              ),
            if (!m.unsent && _inbox != null)
              ListTile(
                leading: const Icon(Icons.shortcut_rounded),
                title: Text(s.forward),
                onTap: () => Navigator.of(sheet).pop('forward'),
              ),
            // Their messages can be reported, quoted exactly as sent.
            if (!mine && !m.unsent && _inbox?.safety != null)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.loss),
                title: Text(
                  s.report,
                  style: const TextStyle(color: AppColors.loss),
                ),
                onTap: () => Navigator.of(sheet).pop('report'),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.loss,
              ),
              title: Text(
                s.deleteForMe,
                style: const TextStyle(color: AppColors.loss),
              ),
              onTap: () => Navigator.of(sheet).pop('hide'),
            ),
            if (mine && !m.pending && !m.unsent)
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

    if (action == 'reply') {
      _startReply(m);
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.copied)));
    } else if (action == 'forward') {
      await _forward(m);
    } else if (action == 'hide') {
      _hide(m);
    } else if (action == 'unsend') {
      await _confirmUnsend(m);
    } else if (action == 'report') {
      await showReportSheet(
        context,
        ReportTarget.message(
          targetUid: widget.otherUid,
          targetUsername: widget.otherUsername,
          chatId: widget.chatId,
          messageId: m.id,
          quote: m.text,
        ),
      );
    }
  }

  /// Sends a copy of [m], marked forwarded, to the conversations picked.
  Future<void> _forward(ChatMessage m) async {
    final inbox = _inbox;
    final repo = _repo;
    if (inbox == null || repo == null) return;
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final myUsername = context.session.profile?.username ?? '';

    final targets = await pickForwardTargets(context, inbox);
    if (targets == null || targets.isEmpty) return;

    final failed = <String>[];
    await Future.wait([
      for (final t in targets)
        repo
            .send(
              chatId: t.id,
              me: _me,
              other: t.otherUid(_me),
              text: m.text,
              forwarded: true,
            )
            .catchError((Object e) {
              debugPrint('forward to ${t.id} failed: $e');
              failed.add(t.otherUsername(myUsername));
            }),
    ]);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty
              ? s.forwardedTo(targets.length)
              : s.forwardFailed(failed.first),
        ),
      ),
    );
  }

  /// "Delete for me": gone from this side at once, with a moment to take it
  /// back. The other person still has it.
  void _hide(ChatMessage m) {
    final repo = _repo;
    if (repo == null) return;
    final s = context.s;
    repo
        .hideMessage(widget.chatId, _me, m.id)
        .catchError((Object e) => debugPrint('delete for me failed: $e'));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.messageDeleted),
          action: SnackBarAction(
            label: s.undo,
            textColor: AppColors.brand,
            onPressed: () => repo
                .unhideMessage(widget.chatId, _me, m.id)
                .catchError((Object e) => debugPrint('undo failed: $e')),
          ),
        ),
      );
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
    _flashTimer?.cancel();
    _inputFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_inbox?.openChatId == widget.chatId) _inbox?.openChatId = null;
    _threadSub?.cancel();
    _latestSub?.cancel();
    _connectedSub?.cancel();
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
    final prefs = _prefs;
    final muted = prefs.mutedAt(now);

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
            _NotConnected(
              text: _blockedMe ? s.cantReplyHere : s.notConnectedToMessage,
            )
          else
            _Composer(
              controller: _input,
              focusNode: _inputFocus,
              hint: s.typeMessage,
              enabled: _connected == true,
              onSend: _send,
              above: _replyBar(s),
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
    final prefs = _prefs;
    final visible = [
      for (final m in _messages)
        if (prefs.shows(m)) m,
    ];
    final nothingOlder = _nothingOlder;

    if (visible.isEmpty && !typing) {
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

    final items = _layout(visible, nothingOlder: nothingOlder);
    final thread = _thread;

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.md),
      itemCount: items.length + (nothingOlder ? 0 : 1) + (typing ? 1 : 0),
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
        final reply = m.replyTo;
        return KeyedSubtree(
          key: _bubbleKeys.putIfAbsent(m.id, GlobalKey.new),
          child: SwipeToReply(
            enabled: _canReply && !m.unsent,
            onReply: () => _startReply(m),
            child: _Bubble(
              message: m,
              mine: mine,
              tail: item.groupEnd,
              time: s.clock(m.sentAt),
              unsentLabel: mine ? s.youUnsent : s.theyUnsent,
              status: mine && thread != null ? statusOf(m, thread, _me) : null,
              quote: reply == null || m.unsent ? null : _quoteFor(reply, s),
              forwardedLabel: m.forwarded && !m.unsent ? s.forwarded : null,
              highlight: _flashId == m.id,
              onLongPress: () => _showActions(m),
            ),
          ),
        );
      },
    );
  }

  /// Messages, newest first, with a day separator above each day and each
  /// run of messages from one person grouped: only the last message of a run
  /// gets a tail and full spacing, as in every chat app.
  List<_Item> _layout(
    List<ChatMessage> messages, {
    required bool nothingOlder,
  }) {
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
      if ((older == null && nothingOlder) ||
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
    this.quote,
    this.forwardedLabel,
    this.highlight = false,
  });

  final ChatMessage message;
  final bool mine;
  final bool tail;
  final String time;
  final String unsentLabel;
  final MessageStatus? status;
  final VoidCallback? onLongPress;

  /// The message this one replies to, drawn above its text.
  final Widget? quote;

  /// "Forwarded", above everything, on a copy from another chat.
  final String? forwardedLabel;

  /// Lit up for a moment after a quote was tapped to get here.
  final bool highlight;

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

    // A reply or a forward stacks its label and quote above the text, all
    // as wide as the widest of them.
    final Widget content = quote == null && forwardedLabel == null
        ? body
        : IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (forwardedLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shortcut_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          forwardedLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (quote != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: quote,
                  ),
                body,
              ],
            ),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: highlight
          ? AppColors.brand.withValues(alpha: 0.16)
          : Colors.transparent,
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
                    child: content,
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
    required this.focusNode,
    required this.hint,
    required this.enabled,
    required this.onSend,
    this.above,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool enabled;
  final VoidCallback onSend;

  /// Shown over the box: the message being replied to.
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?above,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.sm,
                Gap.sm,
                Gap.sm,
                Gap.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
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
                      final ready =
                          enabled && controller.text.trim().isNotEmpty;
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
          ],
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
