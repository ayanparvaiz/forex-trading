import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/room_repository.dart';
import '../data/session_controller.dart';
import '../models/chat.dart';
import '../theme/app_theme.dart';
import 'chat_bits.dart';

/// Most conversations one message can be forwarded to at once, as in
/// WhatsApp — enough to share, too few to spam with.
const maxForwardTargets = 5;

/// Somewhere a message can be forwarded to: a chat, or the Global room.
class ForwardTarget {
  const ForwardTarget.chat(ChatThread this.thread) : isRoom = false;
  const ForwardTarget.global() : thread = null, isRoom = true;

  final ChatThread? thread;
  final bool isRoom;

  String get id => thread?.id ?? RoomRepository.globalId;
}

/// Picks where to forward a message. Null if dismissed.
///
/// The Global room when you have joined it, then your conversations, less
/// anyone you have blocked. One you are no longer connected to is still
/// listed — the send is refused and the caller says so.
Future<List<ForwardTarget>?> pickForwardTargets(
  BuildContext context,
  ChatInbox inbox,
) {
  return showModalBottomSheet<List<ForwardTarget>>(
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
    final targets = [
      if (inbox.rooms != null && inbox.joinedGlobal)
        const ForwardTarget.global(),
      for (final t in inbox.threads)
        if (!inbox.isBlocked(t.otherUid(me))) ForwardTarget.chat(t),
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
            if (targets.isEmpty)
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
                  itemCount: targets.length,
                  itemBuilder: (context, i) {
                    final target = targets[i];
                    final t = target.thread;
                    final partner = t == null
                        ? null
                        : inbox.partner(t.otherUid(me));
                    final username = t?.otherUsername(myUsername) ?? '';
                    final chosen = _chosen.contains(target.id);
                    final canPick = chosen || !full;
                    return ListTile(
                      enabled: canPick,
                      onTap: () => setState(
                        () => chosen
                            ? _chosen.remove(target.id)
                            : _chosen.add(target.id),
                      ),
                      leading: t == null
                          ? const RoomAvatar(size: 42)
                          : ChatAvatar(
                              avatarId: partner?.avatarId ?? 1,
                              activeNow: false,
                              size: 42,
                            ),
                      title: Text(
                        t == null
                            ? s.globalChat
                            : partner?.name.isNotEmpty == true
                            ? partner!.name
                            : '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t == null
                            ? s.members(inbox.global?.memberCount ?? 0)
                            : '@$username',
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
                        for (final t in targets)
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
