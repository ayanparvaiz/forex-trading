import 'package:flutter/material.dart';

import '../data/avatars.dart';
import '../data/community_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/notification_repository.dart';
import '../data/session_controller.dart';
import '../models/app_notification.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

/// Bell with a live unread count.
///
/// The count comes off a Firestore listener, not a fetch, so it moves the
/// moment something happens rather than the next time the screen is rebuilt.
/// A badge that needs a pull-to-refresh is a badge nobody believes.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.repository});

  final NotificationRepository repository;

  @override
  Widget build(BuildContext context) {
    final uid = context.session.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: repository.watchUnreadCount(uid),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NotificationsScreen(repository: repository),
                ),
              ),
              icon: Icon(
                unread > 0
                    ? Icons.notifications
                    : Icons.notifications_none_outlined,
                size: 23,
                color: unread > 0 ? AppColors.brand : AppColors.textSecondary,
              ),
              tooltip: context.s.notifications,
            ),
            if (unread > 0)
              Positioned(
                right: 4,
                top: 4,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 17),
                    decoration: BoxDecoration(
                      color: AppColors.loss,
                      borderRadius: Radii.pill,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: Text(
                      // The stream is capped, so anything at the ceiling is
                      // reported as "lots" rather than a number that is wrong.
                      unread >= 100 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The notification list, live.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.repository});

  final NotificationRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final CommunityRepository _community = buildCommunityRepository(
    context.session.language,
  );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final uid = context.session.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.notifications),
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => widget.repository.markAllRead(uid),
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: Text(s.markAllRead),
            ),
          Gap.w8,
        ],
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<AppNotification>>(
              stream: widget.repository.watch(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      s.couldNotLoad,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.brand,
                    ),
                  );
                }

                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔔', style: TextStyle(fontSize: 34)),
                          Gap.h12,
                          Text(
                            s.noNotifications,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13.5,
                            ),
                          ),
                          Gap.h8,
                          Text(
                            s.notificationsExpire,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.lg,
                    Gap.md,
                    Gap.lg,
                    Gap.xxl,
                  ),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: Gap.lg),
                        child: Text(
                          s.notificationsExpire,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: _NotificationRow(
                        item: items[index],
                        repository: widget.repository,
                        community: _community,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.repository,
    required this.community,
  });

  final AppNotification item;
  final NotificationRepository repository;
  final CommunityRepository community;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return InkWell(
      onTap: () {
        // Reading it is the act of opening it. Marking read on tap rather than
        // on display means the badge still means "you have not looked at this".
        if (!item.read) repository.markRead(item.id);
        openProfile(context, item.actorUsername, community);
      },
      borderRadius: Radii.tile,
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          // Unread rows are lifted rather than coloured, so the list does not
          // turn into a wall of highlights after a quiet week.
          color: item.read ? AppColors.surface : AppColors.elevated,
          borderRadius: Radii.tile,
          border: Border.all(
            color: item.read ? AppColors.border : AppColors.brandDim,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  Avatars.byId(item.actorAvatarId).emoji,
                  style: const TextStyle(fontSize: 26),
                ),
                Positioned(
                  right: -4,
                  bottom: -2,
                  child: Text(
                    item.kind.emoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            Gap.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: item.actorName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: ' ${item.kind.label(s.isBangla)}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.h4,
                  Text(
                    s.timeAgo(item.createdAt),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.read)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
