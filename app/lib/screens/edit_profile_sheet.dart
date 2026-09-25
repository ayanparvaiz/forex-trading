import 'package:flutter/material.dart';

import '../data/avatars.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_image.dart';

/// Edits the signed-in trader's name and avatar. Returns true if saved.
///
/// Only those two. The username is permanent — other people find you by it,
/// and the claim document that reserves it is never rewritten — so it is
/// shown here, but as a fact rather than a field.
Future<bool> showEditProfileSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _EditProfile(),
  );
  return saved ?? false;
}

class _EditProfile extends StatefulWidget {
  const _EditProfile();

  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final _profile = context.session.profile!;
  late final _name = TextEditingController(text: _profile.displayName);
  late int _avatarId = _profile.avatarId;
  bool _saving = false;

  /// Matches the rule on the profile document, so the button refuses what
  /// the server would refuse instead of letting the write fail.
  static const _maxName = 40;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();

  bool get _changed =>
      _trimmed != _profile.displayName || _avatarId != _profile.avatarId;

  bool get _valid => _trimmed.isNotEmpty && _trimmed.length <= _maxName;

  Future<void> _save() async {
    final session = context.session;
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;

    setState(() => _saving = true);
    try {
      await session.updateProfile(
        _profile.copyWith(displayName: _trimmed, avatarId: _avatarId),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(content: Text(s.profileSaved)));
    } catch (error) {
      debugPrint('profile save failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.sm),
            child: Row(
              children: [
                Text(
                  s.editProfile,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: AvatarImage(
                        _avatarId,
                        key: ValueKey(_avatarId),
                        size: 96,
                      ),
                    ),
                  ),
                  Gap.h8,
                  Center(
                    child: Text(
                      '@${_profile.username} · ${s.usernameFixed}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  Gap.h16,
                  Text(
                    s.displayName,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Gap.h8,
                  TextField(
                    controller: _name,
                    maxLength: _maxName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.badge_outlined, size: 19),
                      counterText: '',
                      errorText: _trimmed.length > _maxName
                          ? s.nameTooLong
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  for (final kind in AvatarKind.values) ...[
                    Gap.h16,
                    Text(
                      kind == AvatarKind.animal
                          ? s.avatarAnimals
                          : s.avatarCharacters,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Gap.h8,
                    _AvatarGrid(
                      avatars: Avatars.ofKind(kind).toList(),
                      selected: _avatarId,
                      bangla: s.isBangla,
                      onPick: (id) => setState(() => _avatarId = id),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.sm,
                Gap.lg,
                Gap.md,
              ),
              child: FilledButton(
                onPressed: _changed && _valid && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(s.save),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({
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
