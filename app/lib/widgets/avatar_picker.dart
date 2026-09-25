import 'package:flutter/material.dart';

import '../data/avatars.dart';
import '../theme/app_theme.dart';
import 'avatar_image.dart';

/// Every avatar, on two labelled shelves — animals and characters — with the
/// chosen one outlined. Lays out all of its tiles and lets the page around it
/// scroll, since two dozen small images are nothing to build at once.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selected,
    required this.bangla,
    required this.animalsLabel,
    required this.charactersLabel,
    required this.onPick,
  });

  final int selected;
  final bool bangla;
  final String animalsLabel;
  final String charactersLabel;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in AvatarKind.values) ...[
          if (kind != AvatarKind.values.first) Gap.h16,
          Text(
            kind == AvatarKind.animal ? animalsLabel : charactersLabel,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Gap.h8,
          _AvatarShelf(
            avatars: Avatars.ofKind(kind).toList(),
            selected: selected,
            bangla: bangla,
            onPick: onPick,
          ),
        ],
      ],
    );
  }
}

class _AvatarShelf extends StatelessWidget {
  const _AvatarShelf({
    required this.avatars,
    required this.selected,
    required this.bangla,
    required this.onPick,
  });

  final List<Avatar> avatars;
  final int selected;
  final bool bangla;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      // Inside a scroll view already, so it lays out every tile and lets the
      // sheet do the scrolling — twenty-four small images is nothing to build.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: Gap.sm,
      crossAxisSpacing: Gap.sm,
      childAspectRatio: 0.82,
      children: [
        for (final avatar in avatars)
          _AvatarTile(
            avatar: avatar,
            selected: avatar.id == selected,
            label: avatar.label(bangla),
            onTap: () => onPick(avatar.id),
          ),
      ],
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.avatar,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Avatar avatar;
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
              Expanded(child: AvatarImage(avatar.id, size: 56)),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
