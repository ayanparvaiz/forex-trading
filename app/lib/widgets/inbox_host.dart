import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/chat_repository.dart';
import '../data/room_repository.dart';
import '../data/safety_repository.dart';
import '../data/session_controller.dart';
import '../models/chat.dart';
import '../screens/chat_screen.dart';
import '../screens/room_screen.dart';
import '../theme/app_theme.dart';
import 'avatar_image.dart';
import 'community_badge.dart';

/// Keeps the signed-in trader's inbox alive above every screen, and shows a
/// banner when a message arrives in a conversation you are not looking at.
///
/// Sits in MaterialApp.builder, above the Navigator, because a conversation
/// or a profile is pushed as a sibling of the tab screens rather than inside
/// them — anything below the Navigator would be out of their reach. Up here
/// the inbox is an ancestor of every route, and the banner is drawn over
/// whichever one is showing.
class InboxHost extends StatefulWidget {
  const InboxHost({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<InboxHost> createState() => _InboxHostState();
}

class _InboxHostState extends State<InboxHost> {
  ChatInbox? _inbox;
  String? _uid;
  StreamSubscription<ChatArrival>? _arrivals;

  ChatArrival? _banner;
  Timer? _hide;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A new account gets a new inbox; signing out drops it. Nothing from one
    // person's conversations may survive into another's session.
    final session = SessionScope.of(context);
    final uid = session.uid;
    final communityId = session.profile?.communityId;
    if (uid == _uid) {
      // Joined, switched or left a community: its room comes and goes with it.
      _inbox?.followCommunity(communityId);
      return;
    }
    _uid = uid;
    _teardown();

    final repo = buildChatRepository();
    if (uid == null || repo == null) return;
    final inbox = ChatInbox(
      repository: repo,
      uid: uid,
      safety: buildSafetyRepository(),
      rooms: buildRoomRepository(),
      communityId: communityId,
    );
    _inbox = inbox;
    _arrivals = inbox.arrivals.listen(_show);
  }

  void _show(ChatArrival arrival) {
    _hide?.cancel();
    setState(() => _banner = arrival);
    _hide = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _hide?.cancel();
    if (mounted) setState(() => _banner = null);
  }

  void _openBanner(ChatArrival arrival) {
    _dismiss();
    final session = SessionScope.of(context);
    final me = session.uid;
    final nav = widget.navigatorKey.currentContext;
    if (me == null || nav == null) return;
    final thread = arrival.thread;
    if (thread == null) {
      openRoom(nav, arrival.room?.id ?? RoomRepository.globalId);
      return;
    }
    openChat(
      nav,
      chatId: thread.id,
      otherUid: thread.otherUid(me),
      otherUsername: thread.otherUsername(session.profile?.username ?? ''),
    );
  }

  void _teardown() {
    _arrivals?.cancel();
    _arrivals = null;
    _inbox?.dispose();
    _inbox = null;
    _banner = null;
    _hide?.cancel();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    return InboxScope(
      inbox: _inbox,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -1.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
                child: banner == null
                    ? const SizedBox.shrink()
                    : _Banner(
                        key: ValueKey(banner.messageId),
                        arrival: banner,
                        onTap: () => _openBanner(banner),
                        onDismiss: _dismiss,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.arrival,
    required this.onTap,
    required this.onDismiss,
  });

  final ChatArrival arrival;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final partner = arrival.partner;
    final room = arrival.room;
    final ChatPreview? last = arrival.thread?.lastMessage ?? room?.lastMessage;
    // In a room, whose it was goes in front, as the inbox row shows it.
    final words = last == null
        ? ''
        : context.s.messagePreview(last.text, last.attachmentType);
    final text = room == null ? words : '${last?.senderName ?? ''}: $words';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 0),
      child: Dismissible(
        key: const ValueKey('message-banner'),
        direction: DismissDirection.up,
        onDismissed: (_) => onDismiss(),
        child: Material(
          color: AppColors.overlay,
          elevation: 8,
          shadowColor: Colors.black54,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  if (room != null)
                    RoomPicture(room: room.id, name: room.name, size: 40)
                  else
                    AvatarImage(partner?.avatarId, size: 40),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          room != null
                              ? roomTitle(context.s, room.id, room.name)
                              : partner?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
