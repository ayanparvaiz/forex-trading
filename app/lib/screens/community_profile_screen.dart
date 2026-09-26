import 'dart:async';

import 'package:flutter/material.dart';

import '../data/communities_repository.dart';
import '../data/community_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/session_controller.dart';
import '../models/community.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_image.dart';
import '../widgets/common.dart';
import '../widgets/community_avatar.dart';
import 'profile_screen.dart';

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
  if (leaving != null) {
    final current = await repo.watch(leaving).first.catchError((_) => null);
    if (!context.mounted) return false;
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
/// Anyone can look; members can leave from here, and anyone else can join.
/// The admin — whoever started it — can change the description.
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
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          Row(
            children: [
              CommunityAvatar(id: c.id, name: c.name, size: 72),
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
                    if (mine) ...[
                      Gap.h8,
                      Pill(
                        text: s.yourCommunity,
                        icon: Icons.check_rounded,
                        color: AppColors.brand,
                        dense: true,
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
          if (!mine) ...[
            Gap.h16,
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() => joinCommunity(context, c)),
              icon: const Icon(Icons.group_add_outlined, size: 20),
              label: Text(s.join),
            ),
          ],
          Gap.h24,
          _Members(
            community: c,
            members: _members,
            profiles: _profiles,
            board: _board,
            repository: _social!,
          ),
          if (mine) ...[
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

/// Who is in it: the admin first, then by where each stands on the
/// leaderboard, then by who came first.
class _Members extends StatelessWidget {
  const _Members({
    required this.community,
    required this.members,
    required this.profiles,
    required this.board,
    required this.repository,
  });

  final Community community;
  final List<CommunityMember>? members;
  final Map<String, Trader> profiles;
  final List<Trader> board;
  final CommunityRepository repository;

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
  });

  final CommunityMember member;
  final Trader? trader;
  final bool isAdmin;
  final int? boardRank;
  final CommunityRepository repository;

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
