import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/communities_repository.dart';
import '../data/community_admin.dart';
import '../data/community_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/session_controller.dart';
import '../models/chat.dart';
import '../models/community.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_image.dart';
import '../widgets/common.dart';
import '../widgets/forward_sheet.dart';
import '../widgets/community_badge.dart';
import '../widgets/community_events.dart';
import '../widgets/community_picture_picker.dart';
import '../widgets/community_rules.dart';
import 'profile_screen.dart';
import 'room_screen.dart';

/// Opens community [id]'s page.
Future<void> openCommunity(BuildContext context, String id) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => CommunityProfileScreen(id: id)));

/// Joins [target] — asking first when it means leaving the one you are in,
/// since there is only ever one. True once joined.
Future<bool> joinCommunity(BuildContext context, Community target) async {
  final s = context.s;
  final session = context.session;
  final profile = session.profile;
  final uid = session.uid;
  final repo = buildCommunitiesRepository();
  if (profile == null || uid == null || repo == null) return false;
  final leaving = profile.communityId;
  if (leaving == target.id) return true;
  final messenger = ScaffoldMessenger.of(context);
  if (target.locked) {
    messenger.showSnackBar(
      SnackBar(content: Text(s.communityLocked(target.name))),
    );
    return false;
  }
  // Its rules first: joining is agreeing to them.
  if (!await agreeToRules(context, target) || !context.mounted) return false;
  if (leaving != null) {
    final current = await repo.watch(leaving).first.catchError((_) => null);
    if (!context.mounted) return false;
    // An admin never leaves theirs; they delete it.
    if (current != null && current.createdBy == uid) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.adminOfCommunity(current.name))),
      );
      return false;
    }
    final ok = await _confirm(
      context,
      title: s.switchCommunityTitle,
      body: s.switchCommunityBody(current?.name ?? '…', target.name),
      action: s.switchAction,
      danger: false,
    );
    if (!ok) return false;
  }
  try {
    await repo.join(
      me: uid,
      username: profile.username,
      id: target.id,
      leaving: leaving,
    );
  } catch (e) {
    debugPrint('join community failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    return false;
  }
  session.setCommunity(target.id);
  messenger.showSnackBar(
    SnackBar(content: Text(s.joinedCommunity(target.name))),
  );
  return true;
}

/// Leaves [community], once asked. True once left.
Future<bool> confirmLeaveCommunity(
  BuildContext context,
  Community community,
) async {
  final s = context.s;
  final session = context.session;
  final uid = session.uid;
  final repo = buildCommunitiesRepository();
  if (uid == null || repo == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  if (community.createdBy == uid) {
    messenger.showSnackBar(SnackBar(content: Text(s.adminCantLeave)));
    return false;
  }
  final ok = await _confirm(
    context,
    title: s.leaveCommunityTitle(community.name),
    body: s.leaveCommunityBody,
    action: s.leave,
  );
  if (!ok) return false;
  try {
    await repo.leave(me: uid, id: community.id);
  } catch (e) {
    debugPrint('leave community failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    return false;
  }
  session.setCommunity(null);
  messenger.showSnackBar(
    SnackBar(content: Text(s.leftCommunity(community.name))),
  );
  return true;
}

/// Deletes [community], once its admin is sure: everyone in it leaves, and
/// its chat and posts go. True once deleted.
Future<bool> confirmDeleteCommunity(
  BuildContext context,
  Community community,
) async {
  final s = context.s;
  final session = context.session;
  final admin = communityAdmin;
  if (admin == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await _confirm(
    context,
    title: s.deleteCommunityTitle(community.name),
    body: s.deleteCommunityBody(community.memberCount),
    action: s.deleteAction,
  );
  if (!ok) return false;
  try {
    await admin.delete(community.id);
  } catch (e) {
    debugPrint('delete community failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotChange)));
    return false;
  }
  // The profile follows by itself; this is only sooner.
  session.setCommunity(null);
  messenger.showSnackBar(
    SnackBar(content: Text(s.communityDeleted(community.name))),
  );
  return true;
}

/// Hands [community] to [member], once its admin is sure. True once done.
Future<bool> confirmMakeAdmin(
  BuildContext context,
  Community community,
  CommunityMember member,
  String name,
) async {
  final s = context.s;
  final uid = context.session.uid;
  final repo = buildCommunitiesRepository();
  if (uid == null || repo == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await _confirm(
    context,
    title: s.makeAdminTitle(name),
    body: s.makeAdminBody(community.name),
    action: s.makeAdmin,
    danger: false,
  );
  if (!ok) return false;
  try {
    await repo.handOver(id: community.id, from: uid, to: member.uid);
  } catch (e) {
    debugPrint('hand over failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    return false;
  }
  messenger.showSnackBar(SnackBar(content: Text(s.madeAdmin(name))));
  return true;
}

/// Makes [member] a moderator of [community], or a member again. No
/// question first: it is undone the same way. True once done.
Future<bool> toggleModerator(
  BuildContext context,
  Community community,
  CommunityMember member,
  String name, {
  required int moderators,
}) async {
  final s = context.s;
  final repo = buildCommunitiesRepository();
  if (repo == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  final making = !member.isModerator;
  if (making && moderators >= CommunityMember.maxModerators) {
    messenger.showSnackBar(
      SnackBar(content: Text(s.moderatorsFull(CommunityMember.maxModerators))),
    );
    return false;
  }
  try {
    await repo.setModerator(community.id, member.uid, making);
  } catch (e) {
    debugPrint('moderator failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    return false;
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(making ? s.madeModerator(name) : s.moderatorRemoved(name)),
    ),
  );
  return true;
}

/// Takes [member] out of [community], once its admin is sure.
Future<bool> confirmRemoveMember(
  BuildContext context,
  Community community,
  CommunityMember member,
  String name,
) async {
  final s = context.s;
  final admin = communityAdmin;
  if (admin == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await _confirm(
    context,
    title: s.removeMemberTitle(name),
    body: s.removeMemberBody,
    action: s.removeAction,
  );
  if (!ok) return false;
  try {
    await admin.remove(community: community.id, uid: member.uid);
  } catch (e) {
    debugPrint('remove member failed: $e');
    messenger.showSnackBar(SnackBar(content: Text(s.couldNotChange)));
    return false;
  }
  messenger.showSnackBar(SnackBar(content: Text(s.memberRemoved(name))));
  return true;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool danger = true,
}) async {
  final s = context.s;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.elevated,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          style: danger
              ? TextButton.styleFrom(foregroundColor: AppColors.loss)
              : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// A community's page: what it is, where it stands, and who is in it.
///
/// Anyone can look; members can leave from here, and anyone else can join
/// unless it is locked. The admin — whoever started it — changes its
/// picture and description, locks it, removes people, and instead of
/// leaving, deletes it.
class CommunityProfileScreen extends StatefulWidget {
  const CommunityProfileScreen({super.key, required this.id});

  final String id;

  @override
  State<CommunityProfileScreen> createState() => _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends State<CommunityProfileScreen> {
  CommunitiesRepository? _communities;
  CommunityRepository? _social;
  final _subscriptions = <StreamSubscription<Object?>>[];

  Community? _community;
  bool _loaded = false;
  bool _failed = false;

  /// Every community with its points, for this one's points and rank.
  List<(Community, int)> _ranked = const [];

  /// The top of the leaderboard, for where each member stands.
  List<Trader> _board = const [];

  List<CommunityMember>? _members;
  Map<String, Trader> _profiles = const {};

  /// The member count the list was loaded at: a different count means
  /// someone joined or left, and the list is loaded again.
  int? _membersAt;

  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_communities != null) return;
    final session = context.session;
    final communities = buildCommunitiesRepository();
    final social = buildCommunityRepository(
      session.language,
      viewerUid: session.uid,
    );
    _communities = communities;
    _social = social;
    if (communities == null) {
      _loaded = _failed = true;
      return;
    }
    _subscriptions
      ..add(
        communities
            .watch(widget.id)
            .listen(
              (c) {
                setState(() {
                  _community = c;
                  _loaded = true;
                });
                if (c != null && c.memberCount != _membersAt) _loadMembers(c);
              },
              onError: (Object e) {
                debugPrint('community failed: $e');
                setState(() => _loaded = _failed = true);
              },
            ),
      )
      ..add(
        communities
            .watchRanked(social.watchLeaderboard())
            .listen((r) => setState(() => _ranked = r), onError: (_) {}),
      )
      ..add(
        social.watchLeaderboard().listen(
          (b) => setState(() => _board = b),
          onError: (_) {},
        ),
      );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _loadMembers(Community c) async {
    _membersAt = c.memberCount;
    try {
      final members = await _communities!.members(c.id);
      final profiles = await _social!.tradersByUid([
        for (final m in members) m.uid,
      ]);
      if (!mounted) return;
      setState(() {
        _members = members;
        _profiles = {for (final t in profiles) t.id: t};
      });
    } catch (e) {
      debugPrint('members failed: $e');
      _membersAt = null;
      if (mounted) setState(() => _members ??= const []);
    }
  }

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePicture(Community c) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await pickCommunityPicture(context, current: c.avatarId);
    if (picked == null || picked == c.avatarId) return;
    try {
      await _communities!.setAvatar(c.id, picked);
    } catch (e) {
      debugPrint('picture failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  Future<void> _setLocked(Community c, bool locked) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _communities!.setLocked(c.id, locked);
    } catch (e) {
      debugPrint('lock failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  Future<void> _setSlowMode(Community c, int seconds) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _communities!.setSlowMode(c.id, seconds);
    } catch (e) {
      debugPrint('slow mode failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  Future<void> _delete(Community c) async {
    final nav = Navigator.of(context);
    await _run(() async {
      final deleted = await confirmDeleteCommunity(context, c);
      if (deleted) nav.pop();
      return deleted;
    });
  }

  Future<void> _editDescription(Community c) async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _DescriptionDialog(initial: c.description),
    );
    if (text == null || text.trim() == c.description) return;
    try {
      await _communities!.setDescription(c.id, text);
    } catch (e) {
      debugPrint('description failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(s.couldNotSave)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = _community;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: !_loaded
              ? const CircularProgressIndicator()
              : Text(
                  _failed ? s.couldNotLoad : s.communityGone,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
        ),
      );
    }

    final session = context.session;
    final uid = session.uid;
    final mine = session.profile?.communityId == c.id;
    final isAdmin = c.createdBy == uid;
    final index = _ranked.indexWhere((r) => r.$1.id == c.id);
    final points = index < 0 ? null : _ranked[index].$2;
    final rank = index < 0 ? null : index + 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          // Into any chat, as a card that opens it — unless it is locked,
          // when there is nothing to invite anyone to.
          if (!c.locked && InboxScope.of(context) != null)
            IconButton(
              onPressed: () => shareIntoChats(
                context,
                text: '',
                attachment: SharedCommunity(communityId: c.id),
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: s.inviteToCommunity,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          Row(
            children: [
              // The admin changes the picture by tapping it.
              GestureDetector(
                onTap: isAdmin ? () => _changePicture(c) : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CommunityBadge(
                      id: c.id,
                      name: c.name,
                      avatarId: c.avatarId,
                      size: 76,
                    ),
                    if (isAdmin)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.bg, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Gap.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Gap.h4,
                    Text(
                      [
                        s.members(c.memberCount),
                        if (rank != null) s.communityRank(rank),
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (mine || c.locked) ...[
                      Gap.h8,
                      Wrap(
                        spacing: Gap.xs,
                        runSpacing: Gap.xs,
                        children: [
                          if (mine)
                            Pill(
                              text: s.yourCommunity,
                              icon: Icons.check_rounded,
                              color: AppColors.brand,
                              dense: true,
                            ),
                          if (c.locked)
                            Pill(
                              text: s.lockedLabel,
                              icon: Icons.lock_rounded,
                              color: AppColors.warning,
                              dense: true,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (c.description.isNotEmpty || isAdmin) ...[
            Gap.h16,
            if (c.description.isNotEmpty)
              Text(
                c.description,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            if (isAdmin)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _editDescription(c),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: Text(s.editDescription),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.brand,
                  ),
                ),
              ),
          ],
          Gap.h16,
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: s.membersHeading,
                        value: '${c.memberCount}',
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: s.pointsHeading,
                        value: points == null ? '—' : '$points',
                        valueColor: AppColors.brand,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        label: s.rank,
                        value: rank == null ? '—' : '#$rank',
                      ),
                    ),
                  ],
                ),
                Gap.h12,
                Text(
                  s.pointsExplain,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (c.rules.isNotEmpty || isAdmin) ...[
            Gap.h16,
            CommunityRulesCard(community: c, isAdmin: isAdmin),
          ],
          Gap.h16,
          if (mine) ...[
            // Joined with the community: its members' own room, and what
            // it has planned.
            FilledButton.icon(
              onPressed: () => openRoom(context, c.roomId),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              label: Text(s.openChat),
            ),
            Gap.h16,
            CommunityEvents(community: c, isAdmin: isAdmin),
          ] else if (c.locked) ...[
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: Text(s.lockedLabel),
            ),
            Gap.h8,
            Text(
              s.communityLocked(c.name),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ] else
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() => joinCommunity(context, c)),
              icon: const Icon(Icons.group_add_outlined, size: 20),
              label: Text(s.join),
            ),
          if (isAdmin) ...[
            Gap.h16,
            SectionCard(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md,
                Gap.md,
                Gap.md,
              ),
              child: Row(
                children: [
                  Icon(
                    c.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: c.locked
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.lockCommunity,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.lockHint,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: c.locked,
                    onChanged: _busy ? null : (v) => _setLocked(c, v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.warning,
                  ),
                ],
              ),
            ),
            Gap.h12,
            SectionCard(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: c.slowSeconds > 0
                            ? AppColors.brand
                            : AppColors.textSecondary,
                      ),
                      Gap.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.slowMode,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.slowModeHint,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Gap.h12,
                  // Chips that wrap: five choices are wider than a small
                  // phone's card.
                  Wrap(
                    spacing: Gap.xs,
                    runSpacing: Gap.xs,
                    children: [
                      for (final seconds in Community.slowModes)
                        ChoiceChip(
                          label: Text(s.slowModeEvery(seconds)),
                          selected: c.slowSeconds == seconds,
                          showCheckmark: false,
                          onSelected: _busy
                              ? null
                              : (_) => _setSlowMode(c, seconds),
                          backgroundColor: AppColors.elevated,
                          selectedColor: AppColors.brandDim,
                          side: BorderSide(
                            color: c.slowSeconds == seconds
                                ? AppColors.brand
                                : AppColors.border,
                          ),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          Gap.h24,
          _Members(
            community: c,
            members: _members,
            profiles: _profiles,
            board: _board,
            repository: _social!,
            // The admin can take anyone else out, or hand it to them.
            onAction: isAdmin && !_busy
                ? (m, name, action) => _run(
                    () => switch (action) {
                      _MemberAction.makeAdmin => confirmMakeAdmin(
                        context,
                        c,
                        m,
                        name,
                      ),
                      _MemberAction.moderator =>
                        toggleModerator(
                          context,
                          c,
                          m,
                          name,
                          moderators:
                              _members?.where((x) => x.isModerator).length ?? 0,
                        ).then((done) {
                          // The list is fetched, not followed: fetch it again.
                          if (done) _loadMembers(c);
                          return done;
                        }),
                      _MemberAction.remove => confirmRemoveMember(
                        context,
                        c,
                        m,
                        name,
                      ),
                    },
                  )
                : null,
          ),
          if (isAdmin) ...[
            Gap.h8,
            Text(
              s.moderatorsCan,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            Gap.h24,
            Text(
              s.adminCantLeave,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : () => _delete(c),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_outlined, size: 19),
                label: Text(s.deleteCommunity),
                style: TextButton.styleFrom(foregroundColor: AppColors.loss),
              ),
            ),
          ] else if (mine) ...[
            Gap.h24,
            Center(
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(() => confirmLeaveCommunity(context, c)),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(s.leaveCommunity),
                style: TextButton.styleFrom(foregroundColor: AppColors.loss),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What the admin can do to someone in it.
enum _MemberAction { makeAdmin, moderator, remove }

typedef _OnMemberAction =
    void Function(CommunityMember member, String name, _MemberAction action);

/// Who is in it: the admin first, then by where each stands on the
/// leaderboard, then by who came first.
class _Members extends StatelessWidget {
  const _Members({
    required this.community,
    required this.members,
    required this.profiles,
    required this.board,
    required this.repository,
    this.onAction,
  });

  final Community community;
  final List<CommunityMember>? members;
  final Map<String, Trader> profiles;
  final List<Trader> board;
  final CommunityRepository repository;

  /// Set for the admin: what to do with someone, by name.
  final _OnMemberAction? onAction;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final list = members;
    final place = {for (final (i, t) in board.indexed) t.id: i + 1};
    final sorted = [...?list]
      ..sort((a, b) {
        final admin = (b.uid == community.createdBy ? 1 : 0).compareTo(
          a.uid == community.createdBy ? 1 : 0,
        );
        if (admin != 0) return admin;
        final moderator = (b.isModerator ? 1 : 0).compareTo(
          a.isModerator ? 1 : 0,
        );
        if (moderator != 0) return moderator;
        final pa = place[a.username] ?? 1 << 20;
        final pb = place[b.username] ?? 1 << 20;
        if (pa != pb) return pa.compareTo(pb);
        return a.joinedAt.compareTo(b.joinedAt);
      });

    return SectionCard(
      title: '${s.membersHeading} · ${community.memberCount}',
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.sm),
      child: list == null
          ? const Padding(
              padding: EdgeInsets.all(Gap.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: [
                for (final m in sorted)
                  _MemberRow(
                    member: m,
                    trader: profiles[m.username],
                    isAdmin: m.uid == community.createdBy,
                    boardRank: place[m.username],
                    repository: repository,
                    onAction: m.uid == community.createdBy ? null : onAction,
                  ),
              ],
            ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.trader,
    required this.isAdmin,
    required this.boardRank,
    required this.repository,
    this.onAction,
  });

  final CommunityMember member;
  final Trader? trader;
  final bool isAdmin;
  final int? boardRank;
  final CommunityRepository repository;
  final _OnMemberAction? onAction;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final t = trader;
    return InkWell(
      onTap: () => openProfile(context, member.username, repository),
      borderRadius: Radii.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            AvatarImage(t?.avatarId, size: 38),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t?.name ?? member.username,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      '@${member.username}',
                      if (boardRank != null) s.rankOnBoard(boardRank!),
                    ].join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              Pill(
                text: s.communityAdmin,
                icon: Icons.shield_outlined,
                color: AppColors.brand,
                dense: true,
              )
            else if (member.isModerator)
              Pill(
                text: s.moderator,
                icon: Icons.verified_user_outlined,
                color: AppColors.discipline,
                dense: true,
              ),
            if (!isAdmin && onAction != null)
              // Behind a menu, so nobody is removed by a stray tap.
              PopupMenuButton<_MemberAction>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                color: AppColors.elevated,
                onSelected: (action) =>
                    onAction!(member, t?.name ?? '@${member.username}', action),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _MemberAction.makeAdmin,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 19,
                          color: AppColors.brand,
                        ),
                        Gap.w12,
                        Text(s.makeAdmin),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _MemberAction.moderator,
                    child: Row(
                      children: [
                        Icon(
                          member.isModerator
                              ? Icons.remove_moderator_outlined
                              : Icons.verified_user_outlined,
                          size: 19,
                          color: AppColors.discipline,
                        ),
                        Gap.w12,
                        Text(
                          member.isModerator
                              ? s.removeModerator
                              : s.makeModerator,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _MemberAction.remove,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_remove_outlined,
                          size: 19,
                          color: AppColors.loss,
                        ),
                        Gap.w12,
                        Text(
                          s.removeFromCommunity,
                          style: const TextStyle(color: AppColors.loss),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The admin's box for the description, counted down to its limit.
class _DescriptionDialog extends StatefulWidget {
  const _DescriptionDialog({required this.initial});

  final String initial;

  @override
  State<_DescriptionDialog> createState() => _DescriptionDialogState();
}

class _DescriptionDialogState extends State<_DescriptionDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      backgroundColor: AppColors.elevated,
      title: Text(s.editDescription),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        maxLength: Community.descriptionMax,
        decoration: InputDecoration(hintText: s.communityDescriptionHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(s.save),
        ),
      ],
    );
  }
}
