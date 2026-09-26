import 'package:flutter/material.dart';

import '../data/feed_scope.dart';
import '../data/session_controller.dart';
import '../models/community.dart';
import '../screens/communities_screen.dart';
import '../theme/app_theme.dart';
import 'chat_bits.dart';
import 'community_avatar.dart';

/// A feed by its name and picture: the globe and Global, or a community's.
///
/// [community] is the one [scope] names, when it is not Global; until it has
/// loaded the name is a placeholder rather than a wrong one.
class FeedLabel extends StatelessWidget {
  const FeedLabel({
    super.key,
    required this.scope,
    this.community,
    this.size = 26,
    this.style,
  });

  final String scope;
  final Community? community;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final global = scope == FeedScope.global;
    final c = community;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (global)
          RoomAvatar(size: size)
        else
          CommunityAvatar(id: scope, name: c?.name ?? '', size: size),
        SizedBox(width: size * 0.35),
        Flexible(
          child: Text(
            global ? s.globalChat : c?.name ?? '…',
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Asks which feed: Global, or the community you are in — or, in none, shows
/// the way into one. The chosen feed, or null if nothing was chosen.
Future<String?> pickFeed(
  BuildContext context, {
  required String current,
  required String? communityId,
  Community? community,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheet) {
      final s = sheet.s;
      Widget option({
        required Widget leading,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
        bool selected = false,
      }) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        leading: leading,
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.brand)
            : null,
        onTap: onTap,
      );

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.lg,
                  Gap.lg,
                  Gap.sm,
                ),
                child: Text(
                  s.whichFeed,
                  style: Theme.of(sheet).textTheme.titleMedium,
                ),
              ),
              option(
                leading: const RoomAvatar(size: 40),
                title: s.globalChat,
                subtitle: s.everyonesPosts,
                selected: current == FeedScope.global,
                onTap: () => Navigator.of(sheet).pop(FeedScope.global),
              ),
              if (communityId != null)
                option(
                  leading: CommunityAvatar(
                    id: communityId,
                    name: community?.name ?? '',
                    size: 40,
                  ),
                  title: community?.name ?? '…',
                  subtitle: s.membersOnly,
                  selected: current == communityId,
                  onTap: () => Navigator.of(sheet).pop(communityId),
                )
              else
                option(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_add_outlined,
                      color: AppColors.brand,
                    ),
                  ),
                  title: s.joinACommunity,
                  subtitle: s.joinOrStart,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    openCommunities(context);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
