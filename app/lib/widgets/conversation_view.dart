import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_inbox.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import 'chat_bits.dart';
import 'forward_sheet.dart';

/// Where one conversation's messages come from and go to — a chat between
/// two people, or a room everyone can join — so [ConversationView] can show
/// either the same way.
abstract class MessageSource {
  /// The id what you delete for yourself here is kept under.
  String get prefsId;

  /// Messages per page: a first page shorter than this is the whole history.
  int get pageSize;

  /// The newest page, live.
  Stream<List<ChatMessage>> watchLatest();

  /// The page before [cursor], newest first.
  Future<List<ChatMessage>> olderThan(Object cursor);

  /// One message, for a reply whose original is not loaded.
  Future<ChatMessage?> message(String id);

  Future<void> send(String text, {ReplyRef? replyTo});

  /// Blanks [m] for everyone. [isLatest] when it is the newest message, so
  /// the preview has to follow.
  Future<void> unsend(ChatMessage m, {required bool isLatest});
}

/// One more thing a long-press on a message can do — reporting, which each
/// kind of conversation files differently.
class MessageAction {
  const MessageAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool danger;
}

/// A conversation's messages and the box to answer in.
///
/// Newest at the bottom, the way every chat app reads. The list is built in
/// reverse so the bottom is where it starts and where new messages land, and
/// scrolling up past the loaded messages fetches the page before them.
///
/// Everything a message can do lives here — reply (swipe it, or long-press),
/// copy, forward, delete for me, unsend — so a chat and the Global room
/// behave the same. What differs, the screen around it decides: the header,
/// who may send, ticks, and what "typing" means.
class ConversationView extends StatefulWidget {
  const ConversationView({
    super.key,
    required this.source,
    required this.me,
    required this.canSend,
    required this.nameOf,
    required this.emptyText,
    this.bottom,
    this.statusOf,
    this.showSenderNames = false,
    this.hiddenSenders = const {},
    this.typing = false,
    this.extraActions,
    this.onDraftChanged,
    this.onBeforeSend,
    this.onMessages,
  });

  final MessageSource source;
  final String me;

  /// Whether the box is open. Replying needs it too.
  final bool canSend;

  /// Whose a message is, for quotes and the reply strip. [message] is the
  /// message itself when it is loaded.
  final String Function(String uid, ChatMessage? message) nameOf;

  /// Shown when there is nothing to show.
  final String emptyText;

  /// Replaces the box — why you cannot send here, or a way to join.
  final Widget? bottom;

  /// The tick on a message of mine, when this conversation has ticks.
  final MessageStatus? Function(ChatMessage m)? statusOf;

  /// In a room, each run of someone's messages starts with their name.
  final bool showSenderNames;

  /// People whose messages are left out — the ones you have blocked, in a
  /// room where the rules cannot keep them out.
  final Set<String> hiddenSenders;

  /// The other person is typing: a bubble under the newest message.
  final bool typing;

  final List<MessageAction> Function(ChatMessage m)? extraActions;

  /// The box changed — for typing marks.
  final ValueChanged<String>? onDraftChanged;

  /// Just before a message goes.
  final VoidCallback? onBeforeSend;

  /// Every time the loaded messages change, newest first.
  final ValueChanged<List<ChatMessage>>? onMessages;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  List<ChatMessage> _messages = const [];
  bool _firstPageIn = false;
  bool _loadingOlder = false;
  bool _noMoreOlder = false;
  StreamSubscription<List<ChatMessage>>? _latestSub;

  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  bool _showJump = false;

  /// The message being replied to, shown above the box until it is sent or
  /// dismissed.
  ChatMessage? _replyTo;

  /// Originals of replies that are not among the loaded messages, fetched
  /// once each. A key with a null value is one that could not be found.
  final Map<String, ChatMessage?> _quoted = {};
  final Set<String> _fetchingQuoted = {};

  /// Each bubble's key, so tapping a quote can scroll to its original.
  final Map<String, GlobalKey> _bubbleKeys = {};

  /// The message just scrolled to from a quote, lit up for a moment.
  String? _flashId;
  Timer? _flashTimer;

  String get _me => widget.me;
  MessageSource get _source => widget.source;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _input.addListener(() => widget.onDraftChanged?.call(_input.text));
    _latestSub = _source.watchLatest().listen((latest) {
      if (!mounted) return;
      setState(() {
        // A first page shorter than a page is the whole conversation.
        if (!_firstPageIn && latest.length < _source.pageSize) {
          _noMoreOlder = true;
        }
        _firstPageIn = true;
        _messages = mergeMessages(_messages, latest);
      });
      widget.onMessages?.call(_messages);
    }, onError: (Object e) => debugPrint('messages stream failed: $e'));
  }

  @override
  void dispose() {
    _latestSub?.cancel();
    _flashTimer?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatInbox? get _inbox => InboxScope.read(context);

  /// What I have deleted for myself here.
  ChatPrefs get _prefs => _inbox?.prefsFor(_source.prefsId) ?? ChatPrefs.none;

  bool _shows(ChatMessage m, ChatPrefs prefs) =>
      prefs.shows(m) && !widget.hiddenSenders.contains(m.senderUid);

  // --- Paging ---------------------------------------------------------------

  void _onScroll() {
    final pos = _scroll.position;
    // Reversed list: the far end is the top, where older messages are.
    if (pos.pixels > pos.maxScrollExtent - 300) _loadOlder();
    final jump = pos.pixels > 500;
    if (jump != _showJump) setState(() => _showJump = jump);
  }

  /// Nothing older to load: the server has no more, or everything older was
  /// deleted with the chat.
  bool get _nothingOlder =>
      _noMoreOlder ||
      (_messages.isNotEmpty && _prefs.clearedBy(_messages.last.sentAt));

  Future<void> _loadOlder() async {
    if (_loadingOlder || _nothingOlder || !_firstPageIn) return;
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
      final older = await _source.olderThan(cursor);
      if (!mounted) return;
      setState(() {
        _messages = mergeMessages(_messages, older);
        if (older.length < _source.pageSize) _noMoreOlder = true;
      });
      widget.onMessages?.call(_messages);
    } catch (e) {
      debugPrint('older messages failed: $e');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  // --- Sending --------------------------------------------------------------

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    widget.onBeforeSend?.call();
    final reply = _replyTo;
    setState(() => _replyTo = null);
    _input.clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);

    // Not awaited: the message shows from the local cache at once, marked
    // pending, and becomes a tick when the server has it.
    _source
        .send(
          text,
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

  // --- Replies --------------------------------------------------------------

  void _startReply(ChatMessage m) {
    if (!widget.canSend || m.unsent) return;
    setState(() => _replyTo = m);
    _inputFocus.requestFocus();
  }

  String _nameOf(String uid, ChatMessage? m) => widget.nameOf(uid, m);

  /// The message a reply answers: from those loaded, or fetched once.
  ChatMessage? _original(ReplyRef ref) {
    for (final m in _messages) {
      if (m.id == ref.id) return m;
    }
    if (_quoted.containsKey(ref.id)) return _quoted[ref.id];
    if (_fetchingQuoted.add(ref.id)) {
      _source
          .message(ref.id)
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
      name: _nameOf(ref.senderUid, original),
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
      if (m.id == id && !_shows(m, _prefs)) return;
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
              name: _nameOf(r.senderUid, r),
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

  // --- Long-press -----------------------------------------------------------

  Future<void> _showActions(ChatMessage m) async {
    final s = context.s;
    final mine = m.senderUid == _me;
    final extra = m.unsent
        ? const <MessageAction>[]
        : widget.extraActions?.call(m) ?? const <MessageAction>[];

    ListTile tile(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool danger = false,
    }) => ListTile(
      leading: Icon(icon, color: danger ? AppColors.loss : null),
      title: Text(
        label,
        style: danger ? const TextStyle(color: AppColors.loss) : null,
      ),
      onTap: onTap,
    );

    final action = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) {
        void pick(Object a) => Navigator.of(sheet).pop(a);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Gap.sm),
              if (widget.canSend && !m.unsent)
                tile(Icons.reply_rounded, s.reply, () => pick('reply')),
              if (!m.unsent)
                tile(Icons.copy_rounded, s.copy, () => pick('copy')),
              if (!m.unsent && _inbox != null)
                tile(Icons.shortcut_rounded, s.forward, () => pick('forward')),
              for (final a in extra)
                tile(a.icon, a.label, () => pick(a), danger: a.danger),
              tile(
                Icons.delete_outline_rounded,
                s.deleteForMe,
                () => pick('hide'),
                danger: true,
              ),
              if (mine && !m.pending && !m.unsent)
                tile(
                  Icons.undo_rounded,
                  s.unsend,
                  () => pick('unsend'),
                  danger: true,
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;

    switch (action) {
      case MessageAction a:
        a.onSelected();
      case 'reply':
        _startReply(m);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.copied)));
      case 'forward':
        await _forward(m);
      case 'hide':
        _hide(m);
      case 'unsend':
        await _confirmUnsend(m);
    }
  }

  /// Sends a copy of [m], marked forwarded, to the conversations picked.
  Future<void> _forward(ChatMessage m) async {
    final inbox = _inbox;
    if (inbox == null) return;
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final myUsername = context.session.profile?.username ?? '';

    final targets = await pickForwardTargets(context, inbox);
    if (targets == null || targets.isEmpty) return;

    final failed = <String>[];
    await Future.wait([
      for (final t in targets)
        inbox.repository
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
  /// back. Everyone else still has it.
  void _hide(ChatMessage m) {
    final inbox = _inbox;
    if (inbox == null) return;
    final s = context.s;
    final repo = inbox.repository;
    final id = _source.prefsId;
    repo
        .hideMessage(id, _me, m.id)
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
                .unhideMessage(id, _me, m.id)
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
    await _source
        .unsend(m, isLatest: _messages.isNotEmpty && _messages.first.id == m.id)
        .catchError((Object e) => debugPrint('unsend failed: $e'));
  }

  // --- Drawing --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // Rebuilt when what I have deleted for myself changes.
    InboxScope.of(context);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              _messageList(s, DateTime.now()),
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
        widget.bottom ??
            _Composer(
              controller: _input,
              focusNode: _inputFocus,
              hint: s.typeMessage,
              enabled: widget.canSend,
              onSend: _send,
              above: _replyBar(s),
            ),
      ],
    );
  }

  Widget _messageList(Strings s, DateTime now) {
    final typing = widget.typing;
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
        if (_shows(m, prefs)) m,
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
            widget.emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final items = layoutMessages(visible, nothingOlder: nothingOlder);

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
            enabled: widget.canSend && !m.unsent,
            onReply: () => _startReply(m),
            child: _Bubble(
              message: m,
              mine: mine,
              tail: item.groupEnd,
              time: s.clock(m.sentAt),
              unsentLabel: mine ? s.youUnsent : s.theyUnsent,
              status: mine ? widget.statusOf?.call(m) : null,
              senderName: widget.showSenderNames && !mine && item.groupStart
                  ? _nameOf(m.senderUid, m)
                  : null,
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
}

/// One row of a conversation: a message, or the day it was sent.
class MessageItem {
  MessageItem.message(
    this.message, {
    required this.groupStart,
    required this.groupEnd,
  }) : day = null;
  MessageItem.day(this.day)
    : message = null,
      groupStart = false,
      groupEnd = false;

  final ChatMessage? message;
  final DateTime? day;

  /// The oldest message of a run from one person — where a room puts the
  /// sender's name.
  final bool groupStart;

  /// The newest of a run — the one with the tail and the full spacing.
  final bool groupEnd;
}

/// Messages, newest first, with a day separator above each day and each run
/// of messages from one person grouped: only the last message of a run gets
/// a tail and full spacing, as in every chat app. The top day separator
/// waits until [nothingOlder] — before that, more of the day may load.
List<MessageItem> layoutMessages(
  List<ChatMessage> messages, {
  required bool nothingOlder,
}) {
  bool sameRun(ChatMessage a, ChatMessage b) =>
      a.senderUid == b.senderUid &&
      dayOf(a.sentAt) == dayOf(b.sentAt) &&
      a.sentAt.difference(b.sentAt).abs() <= const Duration(minutes: 5);

  final out = <MessageItem>[];
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    final newer = i > 0 ? messages[i - 1] : null;
    final older = i + 1 < messages.length ? messages[i + 1] : null;

    out.add(
      MessageItem.message(
        m,
        groupStart: older == null || !sameRun(older, m),
        groupEnd: newer == null || !sameRun(newer, m),
      ),
    );

    // In a reversed list, what comes next is drawn above — so the separator
    // goes after the oldest message of each day.
    if ((older == null && nothingOlder) ||
        (older != null && dayOf(older.sentAt) != dayOf(m.sentAt))) {
      out.add(MessageItem.day(dayOf(m.sentAt)));
    }
  }
  return out;
}

/// A name's colour in a room, fixed per person so a reader learns it.
Color senderColor(String uid) {
  const palette = [
    Color(0xFF53BDEB),
    Color(0xFFFFB02E),
    Color(0xFFFF7AB6),
    Color(0xFF4DD0E1),
    Color(0xFFFF8A4C),
    Color(0xFFA78BFA),
    Color(0xFF00D68F),
  ];
  var h = 0;
  for (final c in uid.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
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
    this.senderName,
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

  /// In a room, the sender's name on the first of their run.
  final String? senderName;

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

    // A name, a forward label or a quote stacks above the text, all as wide
    // as the widest of them.
    final Widget content =
        quote == null && forwardedLabel == null && senderName == null
        ? body
        : IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      senderName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: senderColor(message.senderUid),
                      ),
                    ),
                  ),
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
    const round = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(22)),
      borderSide: BorderSide.none,
    );
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?above,
            Padding(
              padding: const EdgeInsets.all(Gap.sm),
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
                        border: round,
                        enabledBorder: round,
                        focusedBorder: round,
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

/// In place of the box: why you cannot send here, and maybe what to do
/// about it.
class ComposerNote extends StatelessWidget {
  const ComposerNote({
    super.key,
    required this.text,
    this.action,
    this.onAction,
  });

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
