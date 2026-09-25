import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_image.dart';
import '../widgets/avatar_picker.dart';

/// Changes your avatar. Just the avatar: a large preview of the one you are
/// choosing, and every avatar below it on two shelves.
class ChangeAvatarScreen extends StatefulWidget {
  const ChangeAvatarScreen({super.key});

  @override
  State<ChangeAvatarScreen> createState() => _ChangeAvatarScreenState();
}

class _ChangeAvatarScreenState extends State<ChangeAvatarScreen> {
  late final _profile = context.session.profile!;
  late int _avatarId = _profile.avatarId;
  bool _saving = false;

  bool get _canSave => !_saving && _avatarId != _profile.avatarId;

  Future<void> _save() async {
    final session = context.session;
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    setState(() => _saving = true);
    try {
      await session.updateProfile(_profile.copyWith(avatarId: _avatarId));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(s.profileSaved)));
    } catch (e) {
      debugPrint('avatar save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.avatar),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.brand,
                    ),
                  )
                : Text(
                    s.save,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
          Gap.w8,
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
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
                  size: 112,
                ),
              ),
            ),
            Gap.h24,
            AvatarPicker(
              selected: _avatarId,
              bangla: s.isBangla,
              animalsLabel: s.avatarAnimals,
              charactersLabel: s.avatarCharacters,
              onPick: (id) => setState(() => _avatarId = id),
            ),
          ],
        ),
      ),
    );
  }
}
