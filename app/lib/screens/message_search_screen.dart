import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import '../widgets/conversation_view.dart';

/// Searches the conversation [source] — a chat or a room. The id of the
/// message picked, to scroll to; null when nothing was.
Future<String?> searchMessages(
  BuildContext context, {
  required MessageSource source,
  required String Function(String uid, ChatMessage message) nameOf,
  bool Function(ChatMessage m)? shows,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    builder: (_) =>
        MessageSearchScreen(source: source, nameOf: nameOf, shows: shows),
  ),
);

/// Words found in a conversation, newest first.
///
/// The server cannot search inside messages, so this reads them: a few
/// hundred at a time, back from the newest, as far as asked. What is read is
/// searched again as the words change, without reading anything twice.
class MessageSearchScreen extends StatefulWidget {
  const MessageSearchScreen({
    super.key,
    required this.source,
    required this.nameOf,
    this.shows,
  });

  /// Messages read per "look further back".
  static const batch = 300;

  final MessageSource source;
  final String Function(String uid, ChatMessage message) nameOf;

  /// Whether a message is there to find — not deleted for me, nor from
  /// someone I blocked. Everything, when not given.
  final bool Function(ChatMessage m)? shows;

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final _query = TextEditingController();

  /// Read so far, newest first.
  List<ChatMessage> _read = const [];
  bool _loading = false;

  /// Read back to the very first message.
  bool _all = false;

  @override
  void initState() {
    super.initState();
    _readMore();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _readMore() async {
    if (_loading || _all) return;
    setState(() => _loading = true);
    final source = widget.source;
    var read = _read;
    var all = false;
    try {
      var got = 0;
      if (read.isEmpty) {
        final first = await source.watchLatest().first;
        read = mergeMessages(read, first);
        got += first.length;
        all = first.length < source.pageSize;
      }
      while (!all && got < MessageSearchScreen.batch) {
        // The oldest the server has confirmed: where the page before starts.
        Object? cursor;
        for (final m in read.reversed) {
          if (!m.pending && m.cursor != null) {
            cursor = m.cursor;
            break;
          }
        }
        if (cursor == null) {
          all = true;
          break;
        }
        final older = await source.olderThan(cursor);
        read = mergeMessages(read, older);
        got += older.length;
        if (older.length < source.pageSize) all = true;
      }
    } catch (e) {
      debugPrint('search read failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _read = read;
      _all = all;
      _loading = false;
    });
  }

  List<ChatMessage> _matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final shows = widget.shows;
    return [
      for (final m in _read)
        if (!m.unsent &&
            (shows == null || shows(m)) &&
            _searchable(m).toLowerCase().contains(q))
          m,
    ];
  }

  /// A message's words — and a poll's question and answers, which are
  /// words too.
  static String _searchable(ChatMessage m) => switch (m.attachment) {
    Poll(:final question, :final options) => [
      m.text,
      question,
      ...options,
    ].join('\n'),
    _ => m.text,
  };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final query = _query.text;
    final found = _matches(query);
    final readCount = _read.where((m) => !m.unsent).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s.searchChat,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              onPressed: () => setState(_query.clear),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xxl),
        children: [
          if (query.trim().isEmpty)
            _Note(s.searchChatHint)
          else if (found.isEmpty && !_loading)
            _Note(s.nothingFound),
          for (final m in found)
            _Found(
              message: m,
              name: widget.nameOf(m.senderUid, m),
              query: query.trim(),
              text: _searchable(m),
              onTap: () => Navigator.of(context).pop(m.id),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(Gap.lg),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else if (query.trim().isNotEmpty) ...[
            Gap.h12,
            Center(
              child: Text(
                _all ? s.searchedAll : s.searchedLast(readCount),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            if (!_all)
              Center(
                child: TextButton.icon(
                  onPressed: _readMore,
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: Text(s.lookFurtherBack),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Gap.xl),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
    ),
  );
}

/// One message found: who, when, and the words around the match, the match
/// itself in bold.
class _Found extends StatelessWidget {
  const _Found({
    required this.message,
    required this.name,
    required this.query,
    required this.text,
    required this.onTap,
  });

  final ChatMessage message;
  final String name;
  final String query;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ListTile(
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Gap.w8,
          Text(
            _when(s, message.sentAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
      subtitle: Text.rich(
        _highlight(_around(text, query), query),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
      ),
    );
  }

  static String _when(Strings s, DateTime t) {
    final now = DateTime.now();
    final l = t.toLocal();
    final today =
        l.year == now.year && l.month == now.month && l.day == now.day;
    return today ? s.clock(t) : s.shortDate(t);
  }

  /// The words a little before the match on, so a match deep in a long
  /// message still shows.
  static String _around(String text, String query) {
    final flat = text.replaceAll('\n', ' ');
    final at = flat.toLowerCase().indexOf(query.toLowerCase());
    if (at <= 30) return flat;
    return '…${flat.substring(at - 20)}';
  }

  static TextSpan _highlight(String text, String query) {
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    // A letter whose small form is longer would put the bold in the wrong
    // place: none, then.
    if (lower.length != text.length) return TextSpan(text: text);
    var from = 0;
    while (q.isNotEmpty) {
      final at = lower.indexOf(q, from);
      if (at < 0) break;
      if (at > from) spans.add(TextSpan(text: text.substring(from, at)));
      spans.add(
        TextSpan(
          text: text.substring(at, at + q.length),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      );
      from = at + q.length;
    }
    spans.add(TextSpan(text: text.substring(from)));
    return TextSpan(children: spans);
  }
}
