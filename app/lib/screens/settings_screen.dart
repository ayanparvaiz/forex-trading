import 'package:flutter/material.dart';

import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_image.dart';

Future<void> openSettings(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

/// Everything about your account, in one place.
///
/// Grouped the way phone settings are — account, privacy and safety, about —
/// with the two actions that end a session at the bottom, apart from the
/// rest, so neither is tapped on the way to something else.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final session = context.session;
    final profile = session.profile;

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: profile == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md,
                Gap.lg,
                Gap.xxl,
              ),
              children: [
                Row(
                  children: [
                    AvatarImage(profile.avatarId, size: 64),
                    Gap.w16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${profile.username}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Gap.h24,
                SettingsSection(
                  title: s.sectionAccount,
                  children: [
                    SettingsTile(
                      icon: Icons.translate_rounded,
                      title: s.language,
                      trailing: _LanguageSwitch(s: s),
                    ),
                  ],
                ),
                Gap.h24,
                SettingsSection(
                  children: [
                    SettingsTile(
                      icon: Icons.logout_rounded,
                      title: s.logOut,
                      danger: true,
                      onTap: () => _confirmLogOut(context),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _confirmLogOut(BuildContext context) async {
    final s = context.s;
    final session = context.session;
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.elevated,
        title: Text(s.logOutTitle),
        content: Text(s.logOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.loss),
            child: Text(s.logOut),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Back to the root first, so no screen of the old session is left under
    // the login screen.
    nav.popUntil((route) => route.isFirst);
    await session.logOut();
  }
}

/// A titled, rounded group of settings rows.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.sm),
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: Radii.card,
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 56, color: AppColors.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row: an icon, a title, optionally a line under it and something at
/// the end. [danger] colours it for actions that cannot be taken back.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.loss : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: danger ? AppColors.loss : AppColors.textSecondary,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (trailing == null && onTap != null && !danger)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.s});

  final Strings s;

  @override
  Widget build(BuildContext context) {
    final session = context.session;
    return SegmentedButton<AppLanguage>(
      segments: [
        for (final l in AppLanguage.values)
          ButtonSegment(value: l, label: Text(l.nativeName)),
      ],
      selected: {session.language},
      showSelectedIcon: false,
      onSelectionChanged: (v) => session.setLanguage(v.first),
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        selectedBackgroundColor: AppColors.brandDim,
        selectedForegroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
