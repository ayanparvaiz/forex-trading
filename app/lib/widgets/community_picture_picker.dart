import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/community_avatars.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';

/// Asks for a community's picture, from every one on four shelves. The one
/// picked, or null if the sheet was dismissed.
Future<int?> pickCommunityPicture(BuildContext context, {int? current}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheet) {
      final s = sheet.s;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.choosePicture,
                      style: Theme.of(sheet).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheet).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg,
                  Gap.sm,
                  Gap.lg,
                  Gap.xl,
                ),
                child: CommunityPicturePicker(
                  selected: current,
                  onPick: (id) => Navigator.of(sheet).pop(id),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Every community picture, a shelf per topic.
class CommunityPicturePicker extends StatelessWidget {
  const CommunityPicturePicker({
    super.key,
    required this.selected,
    required this.onPick,
  });

  final int? selected;
  final ValueChanged<int> onPick;

  static String topicLabel(Strings s, CommunityAvatarTopic topic) =>
      switch (topic) {
        CommunityAvatarTopic.market => s.topicMarket,
        CommunityAvatarTopic.discipline => s.topicDiscipline,
        CommunityAvatarTopic.nature => s.topicNature,
        CommunityAvatarTopic.emblem => s.topicEmblem,
      };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final topic in CommunityAvatarTopic.values) ...[
          if (topic != CommunityAvatarTopic.values.first) Gap.h16,
          Text(
            topicLabel(s, topic),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Gap.h8,
          GridView.count(
            // Inside the sheet's scroll view: every tile laid out, the sheet
            // does the scrolling.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: Gap.sm,
            crossAxisSpacing: Gap.sm,
            childAspectRatio: 0.82,
            children: [
              for (final picture in CommunityAvatars.ofTopic(topic))
                _Tile(
                  picture: picture,
                  selected: picture.id == selected,
                  label: picture.label(s.isBangla),
                  onTap: () => onPick(picture.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.picture,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final CommunityAvatar picture;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandDim : AppColors.elevated,
            borderRadius: Radii.tile,
            border: Border.all(
              color: selected ? AppColors.brand : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: SvgPicture.asset(picture.asset, width: 56, height: 56),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
