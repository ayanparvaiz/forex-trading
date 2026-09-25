import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/session_controller.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import 'chat_bits.dart';

/// Most conversations one message can be forwarded to at once, as in
/// WhatsApp — enough to share, too few to spam with.
const maxForwardTargets = 5;

/// Picks the conversations to forward a message to. Null if dismissed.
///
/// Your conversations, less anyone you have blocked. One you are no longer
/// connected to is still listed — the send is refused and the caller says so.
Future<List<ChatThread>?> pickForwardTargets(
  BuildContext context,
  ChatInbox inbox,
) {
  return showModalBottomSheet<List<ChatThread>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ForwardSheet(inbox: inbox),
  );
}

class _ForwardSheet extends StatefulWidget {
  const _ForwardSheet({required this.inbox});

  final ChatInbox inbox;

  @override
  State<_ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends State<_ForwardSheet> {
  final _chosen = <String>{};

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final inbox = widget.inbox;
    final me = inbox.uid;
    final myUsername = context.session.profile?.username ?? '';
    final threads = [
      for (final t in inbox.threads)
        if (!inbox.isBlocked(t.otherUid(me))) t,
    ];
    final full = _chosen.length >= maxForwardTargets;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, 4),
              child: Text(
                s.forwardTo,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Text(
                s.forwardLimit,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Gap.h8,
            if (threads.isEmpty)
              Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: Text(
                  s.noChatsToForward,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: threads.length,
                  itemBuilder: (context, i) {
                    final t = threads[i];
                    final partner = inbox.partner(t.otherUid(me));
                    final username = t.otherUsername(myUsername);
                    final chosen = _chosen.contains(t.id);
                    final canPick = chosen || !full;
                    return ListTile(
                      enabled: canPick,
                      onTap: () => setState(
                        () => chosen ? _chosen.remove(t.id) : _chosen.add(t.id),
                      ),
                      leading: ChatAvatar(
                        avatarId: partner?.avatarId ?? 1,
                        activeNow: false,
                        size: 42,
                      ),
                      title: Text(
                        partner?.name.isNotEmpty == true
                            ? partner!.name
                            : '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '@$username',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      trailing: Icon(
                        chosen
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: chosen ? AppColors.brand : AppColors.textMuted,
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.md,
              ),
              child: FilledButton.icon(
                onPressed: _chosen.isEmpty
                    ? null
                    : () => Navigator.of(context).pop([
                        for (final t in threads)
                          if (_chosen.contains(t.id)) t,
                      ]),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _chosen.isEmpty ? s.send : '${s.send} (${_chosen.length})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
