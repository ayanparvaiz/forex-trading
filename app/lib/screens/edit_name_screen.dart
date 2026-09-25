import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../theme/app_theme.dart';

/// Changes the name other people see. Just the name.
///
/// The username is not editable and is shown here only as a fact: other
/// people find you by it, and the claim that reserves it is never rewritten.
class EditNameScreen extends StatefulWidget {
  const EditNameScreen({super.key});

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  late final _profile = context.session.profile!;
  late final _name = TextEditingController(text: _profile.displayName);
  bool _saving = false;

  /// The same limit the rules enforce on the profile document, so Save
  /// refuses what the server would refuse instead of letting the write fail.
  static const _max = 40;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _trimmed => _name.text.trim();
  bool get _canSave =>
      !_saving &&
      _trimmed.isNotEmpty &&
      _trimmed.length <= _max &&
      _trimmed != _profile.displayName;

  Future<void> _save() async {
    final session = context.session;
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    setState(() => _saving = true);
    try {
      await session.updateProfile(_profile.copyWith(displayName: _trimmed));
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(s.profileSaved)));
    } catch (e) {
      debugPrint('name save failed: $e');
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
        title: Text(s.displayName),
        actions: [
          ListenableBuilder(
            listenable: _name,
            builder: (context, _) => TextButton(
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
          ),
          Gap.w8,
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: _max,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _canSave ? _save() : null,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge_outlined, size: 19),
              ),
            ),
            Gap.h8,
            Text(
              s.nameVisibleTo,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            Gap.h24,
            Text(s.username, style: Theme.of(context).textTheme.labelSmall),
            Gap.h8,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: Radii.field,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alternate_email,
                    size: 19,
                    color: AppColors.textMuted,
                  ),
                  Gap.w12,
                  Expanded(
                    child: Text(
                      _profile.username,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.lock_outline,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            Gap.h8,
            Text(
              s.usernameFixed,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
