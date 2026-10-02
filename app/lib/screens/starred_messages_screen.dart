import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/session_controller.dart';
import '../data/starred_messages.dart';
import '../i18n/strings.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import '../widgets/community_badge.dart';
import 'chat_screen.dart';
import 'room_screen.dart';

/// Opens the messages starred.
Future<void> openStarredMessages(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const StarredMessagesScreen()));

/// Every message starred, newest star first: where it was, who said it, and
/// what — as it is now. Tapped, the conversation opens at it.
class StarredMessagesScreen extends StatefulWidget {
  const StarredMessagesScreen({super.key, this.store});

  /// Where the stars are; Firestore unless a test says otherwise.
  final StarredMessages? store;

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  late final StarredMessages? _store = widget.store ?? buildStarredMessages();
  StreamSubscription<List<StarredRef>>? _following;
  List<StarredRef>? _refs;

  /// Each message, read once. A key with null is one that is gone.
  final Map<String, ChatMessage?> _messages = {};
  final Set<String> _reading = {};

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final uid = context.session.uid;
    if (uid == null) return;
    _following = _store
        ?.watchAll(uid)
        .listen(
          (refs) => setState(() => _refs = refs),
          onError: (Object e) {
            debugPrint('starred failed: $e');
            if (mounted) setState(() => _refs ??= const []);
          },
        );
  }

  @override
  void dispose() {
    _following?.cancel();
    super.dispose();
  }

  ChatMessage? _messageOf(StarredRef ref) {
    if (_messages.containsKey(ref.id)) return _messages[ref.id];
    if (_reading.add(ref.id)) {
      _store?.message(ref).then((m) {
        if (mounted) setState(() => _messages[ref.id] = m);
      });
    }
    return null;
  }

  Future<void> _unstar(StarredRef ref) async {
    final uid = context.session.uid;
    if (uid == null) return;
    try {
      await _store?.unstar(uid, ref.conversationId, ref.messageId);
    } catch (e) {
      debugPrint('unstar failed: $e');
    }
  }

  void _open(StarredRef ref) {
    if (ref.room) {
      openRoom(context, ref.conversationId, jumpTo: ref.messageId);
      return;
    }
    final uid = ref.otherUid;
    final username = ref.otherUsername;
    if (uid == null || username == null) return;
    openChat(
      context,
      chatId: ref.conversationId,
      otherUid: uid,
      otherUsername: username,
      jumpTo: ref.messageId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final refs = _refs;
    return Scaffold(
      appBar: AppBar(title: Text(s.starredMessages)),
      body: switch (refs) {
        null when _store != null => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        null || [] => Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Text(
              _store == null ? s.messagingNeedsServer : s.noStarred,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        final list => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: Gap.sm),
          itemCount: list.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: Gap.lg, endIndent: Gap.lg),
          itemBuilder: (context, i) {
            final ref = list[i];
            return _StarredTile(
              place: _placeOf(ref, s),
              message: _messageOf(ref),
              loading: !_messages.containsKey(ref.id),
              who: (m) => _whoOf(ref, m, s),
              onTap: () => _open(ref),
              onUnstar: () => _unstar(ref),
            );
          },
        ),
      },
    );
  }

  /// Where it was said: the room, or who the chat is with.
  String _placeOf(StarredRef ref, Strings s) {
    final inbox = InboxScope.of(context);
    if (ref.room) {
      return roomTitle(
        s,
        ref.conversationId,
        inbox?.room(ref.conversationId)?.name ?? '',
      );
    }
    final partner = ref.otherUid == null ? null : inbox?.partner(ref.otherUid!);
    return partner?.name ?? '@${ref.otherUsername ?? ''}';
  }

  String _whoOf(StarredRef ref, ChatMessage m, Strings s) {
    if (m.senderUid == context.session.uid) return s.you;
    if (ref.room) return m.senderName ?? '…';
    final partner = ref.otherUid == null
        ? null
        : InboxScope.of(context)?.partner(ref.otherUid!);
    return partner?.name ?? '@${ref.otherUsername ?? ''}';
  }
}

class _StarredTile extends StatelessWidget {
  const _StarredTile({
    required this.place,
    required this.message,
    required this.loading,
    required this.who,
    required this.onTap,
    required this.onUnstar,
  });

  final String place;
  final ChatMessage? message;
  final bool loading;
  final String Function(ChatMessage m) who;
  final VoidCallback onTap;
  final VoidCallback onUnstar;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final m = message;
    final gone = m == null || m.unsent;
    return ListTile(
      onTap: gone ? null : onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(
              gone || loading ? place : '${who(m)} · $place',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (m != null) ...[
            Gap.w8,
            Text(
              s.shortDate(m.sentAt),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          loading
              ? '…'
              : gone
              ? s.starredGone
              : m.text.isNotEmpty
              ? m.text
              : s.messagePreview('', m.attachment?.type),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            fontStyle: gone && !loading ? FontStyle.italic : null,
            color: gone ? AppColors.textMuted : AppColors.textSecondary,
          ),
        ),
      ),
      trailing: IconButton(
        onPressed: onUnstar,
        tooltip: s.unstarMessage,
        icon: const Icon(Icons.star_rounded, color: AppColors.warning),
      ),
    );
  }
}
