import 'package:flutter/material.dart';

import '../data/support_repository.dart';
import '../data/chat_inbox.dart';
import '../data/communities_repository.dart';
import '../data/push.dart';
import '../data/loss_limit.dart';
import '../data/session_controller.dart';
import '../data/trade_checklist_pref.dart';
import '../i18n/strings.dart';
import '../legal/legal_text.dart';
import '../models/community.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_image.dart';
import '../widgets/community_badge.dart';
import 'blocked_accounts_screen.dart';
import 'change_avatar_screen.dart';
import 'change_password_screen.dart';
import 'communities_screen.dart';
import 'delete_account_screen.dart';
import 'edit_name_screen.dart';
import 'legal_screen.dart';
import 'saved_posts_screen.dart';
import 'support_screen.dart';
import 'starred_messages_screen.dart';

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
                      icon: Icons.badge_outlined,
                      title: s.displayName,
                      subtitle: profile.displayName,
                      onTap: () => _push(context, const EditNameScreen()),
                    ),
                    SettingsTile(
                      icon: Icons.face_retouching_natural_outlined,
                      title: s.avatar,
                      trailing: AvatarImage(profile.avatarId, size: 32),
                      onTap: () => _push(context, const ChangeAvatarScreen()),
                    ),
                    SettingsTile(
                      icon: Icons.password_rounded,
                      title: s.changePassword,
                      onTap: () => _push(context, const ChangePasswordScreen()),
                    ),
                    SettingsTile(
                      icon: Icons.bookmark_border,
                      title: s.savedPosts,
                      onTap: () => openSavedPosts(context),
                    ),
                    SettingsTile(
                      icon: Icons.star_outline_rounded,
                      title: s.starredMessages,
                      onTap: () => openStarredMessages(context),
                    ),
                    SettingsTile(
                      icon: Icons.translate_rounded,
                      title: s.language,
                      trailing: _LanguageSwitch(s: s),
                    ),
                  ],
                ),
                Gap.h24,
                SettingsSection(
                  title: s.sectionTrading,
                  children: const [_ChecklistTile(), LossLimitTile()],
                ),
                if (buildCommunitiesRepository() != null) ...[
                  Gap.h24,
                  SettingsSection(
                    title: s.communities,
                    children: const [_CommunityTile()],
                  ),
                ],
                if (pushService != null) ...[
                  Gap.h24,
                  SettingsSection(
                    title: s.notifications,
                    children: const [_PushTile()],
                  ),
                ],
                Gap.h24,
                SettingsSection(
                  title: s.sectionPrivacy,
                  children: [
                    SettingsTile(
                      icon: Icons.block,
                      title: s.blockedAccounts,
                      subtitle: switch (InboxScope.of(
                        context,
                      )?.blocked.length) {
                        null || 0 => null,
                        final n => '$n',
                      },
                      onTap: () =>
                          _push(context, const BlockedAccountsScreen()),
                    ),
                  ],
                ),
                Gap.h24,
                SettingsSection(
                  title: s.sectionAbout,
                  children: [
                    if (buildSupport() != null)
                      SettingsTile(
                        icon: Icons.support_agent_outlined,
                        title: s.writeToAdmins,
                        onTap: () => openSupport(context),
                      ),
                    SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: privacyPolicy(session.language).title,
                      onTap: () => openLegal(context, LegalPage.privacy),
                    ),
                    SettingsTile(
                      icon: Icons.gavel_rounded,
                      title: termsOfUse(session.language).title,
                      onTap: () => openLegal(context, LegalPage.terms),
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
                    SettingsTile(
                      icon: Icons.delete_forever_outlined,
                      title: s.deleteAccount,
                      danger: true,
                      onTap: () => _push(context, const DeleteAccountScreen()),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static Future<void> _push(BuildContext context, Widget screen) =>
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));

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
            if (trailing != null) Flexible(child: trailing!),
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

/// The community you are in, or the way into one.
class _CommunityTile extends StatefulWidget {
  const _CommunityTile();

  @override
  State<_CommunityTile> createState() => _CommunityTileState();
}

class _CommunityTileState extends State<_CommunityTile> {
  final _repo = buildCommunitiesRepository();
  String? _id;
  Stream<Community?>? _community;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final id = context.session.profile?.communityId;
    if (id != _id) {
      _id = id;
      _community = id == null ? null : _repo?.watch(id);
    }
    return StreamBuilder<Community?>(
      stream: _community,
      builder: (context, snap) => SettingsTile(
        icon: Icons.groups_2_outlined,
        title: s.yourCommunity,
        subtitle: id == null ? s.joinOrStart : snap.data?.name ?? '…',
        trailing: switch (snap.data) {
          final c? => CommunityBadge(
            id: c.id,
            name: c.name,
            avatarId: c.avatarId,
            size: 32,
          ),
          null => null,
        },
        onTap: () => openCommunities(context),
      ),
    );
  }
}

/// Push notifications on this phone, on or off.
/// The daily loss limit: what it is, what is waiting for tomorrow, and a
/// sheet to change it.
class LossLimitTile extends StatefulWidget {
  const LossLimitTile({super.key, this.limit});

  /// The app's [lossLimit] unless a test says otherwise.
  final LossLimit? limit;

  @override
  State<LossLimitTile> createState() => _LossLimitTileState();
}

class _LossLimitTileState extends State<LossLimitTile> {
  late final LossLimit _limit = widget.limit ?? lossLimit;

  @override
  void initState() {
    super.initState();
    _limit.addListener(_refresh);
    _limit.load();
  }

  @override
  void dispose() {
    _limit.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pick() async {
    final s = context.s;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.dailyLossLimit,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
              Gap.h8,
              Text(
                s.lossLimitExplain,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              Gap.h8,
              for (final pct in LossLimit.choices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Navigator.of(sheet).pop(pct),
                  leading: Icon(
                    (_limit.pending ?? _limit.percent) == pct
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: AppColors.brand,
                  ),
                  title: Text(s.lossLimitValue(pct)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await _limit.set(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final pending = _limit.pending;
    return SettingsTile(
      icon: Icons.front_hand_outlined,
      title: s.dailyLossLimit,
      subtitle: [
        s.lossLimitValue(_limit.percent),
        if (pending != null) s.lossLimitPending(pending),
      ].join(' · '),
      onTap: _pick,
    );
  }
}

/// The checklist before each trade, on or off.
class _ChecklistTile extends StatefulWidget {
  const _ChecklistTile();

  @override
  State<_ChecklistTile> createState() => _ChecklistTileState();
}

class _ChecklistTileState extends State<_ChecklistTile> {
  final _pref = TradeChecklistPref();
  bool? _on;

  @override
  void initState() {
    super.initState();
    _pref.isOn().then((on) {
      if (mounted) setState(() => _on = on);
    });
  }

  void _toggle(bool on) {
    setState(() => _on = on);
    _pref.set(on);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SettingsTile(
      icon: Icons.checklist_rounded,
      title: s.tradeChecklist,
      subtitle: s.tradeChecklistHint,
      trailing: Switch(
        value: _on ?? true,
        onChanged: _on == null ? null : _toggle,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.brand,
      ),
    );
  }
}

class _PushTile extends StatefulWidget {
  const _PushTile();

  @override
  State<_PushTile> createState() => _PushTileState();
}

class _PushTileState extends State<_PushTile> {
  bool? _on;
  bool _busy = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final uid = context.session.uid;
    if (uid == null) return;
    pushService?.preference(uid).then((on) {
      if (mounted) setState(() => _on = on ?? false);
    });
  }

  Future<void> _toggle(bool on) async {
    final push = pushService;
    final session = context.session;
    final uid = session.uid;
    if (push == null || uid == null) return;
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (on) {
        final allowed = await push.enable(uid, session.language.code);
        // Once a phone has said no, only its own Settings can say yes.
        if (!allowed) {
          messenger.showSnackBar(SnackBar(content: Text(s.pushBlockedByPhone)));
        }
        if (mounted) setState(() => _on = allowed);
      } else {
        await push.disable(uid);
        if (mounted) setState(() => _on = false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SettingsTile(
      icon: Icons.notifications_active_outlined,
      title: s.pushNotifications,
      subtitle: s.pushNotificationsHint,
      trailing: Switch(
        value: _on ?? false,
        onChanged: _busy || _on == null ? null : _toggle,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.brand,
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
