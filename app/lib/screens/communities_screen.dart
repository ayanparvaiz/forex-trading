import 'package:flutter/material.dart';

import '../data/communities_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/session_controller.dart';
import '../models/community.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/community_avatar.dart';
import 'community_profile_screen.dart';
import 'start_community_screen.dart';

/// Opens the list of communities.
Future<void> openCommunities(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const CommunitiesScreen()));

/// Every community, best first, with yours on top.
///
/// Best means points: members high on the leaderboard count for more than
/// members in number, so a small community of careful traders can outrank a
/// big one. Anyone can join any of them, no approval — one at a time.
class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  CommunitiesRepository? _repo;
  Stream<List<(Community, int)>>? _ranked;

  /// Which community is joining, so only its button spins.
  String? _joining;

  /// Yours on its own, for when it is past the end of the list.
  (String, Stream<Community?>)? _mine;

  Stream<Community?>? _watchMine(String id) {
    if (_mine?.$1 != id) {
      final stream = _repo?.watch(id);
      _mine = stream == null ? null : (id, stream);
    }
    return _mine?.$2;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ranked != null) return;
    _watch();
  }

  void _watch() {
    final session = context.session;
    _repo = buildCommunitiesRepository();
    final social = buildCommunityRepository(
      session.language,
      viewerUid: session.uid,
    );
    _ranked = _repo?.watchRanked(social.watchLeaderboard());
  }

  Future<void> _join(Community c) async {
    setState(() => _joining = c.id);
    try {
      await joinCommunity(context, c);
    } finally {
      if (mounted) setState(() => _joining = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final mine = context.session.profile?.communityId;

    return Scaffold(
      appBar: AppBar(title: Text(s.communities)),
      body: StreamBuilder<List<(Community, int)>>(
        stream: _ranked,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Retry(onRetry: () => setState(_watch));
          }
          final ranked = snap.data;
          final myIndex = ranked?.indexWhere((r) => r.$1.id == mine) ?? -1;

          return ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
            children: [
              _Heading(s.yourCommunity),
              if (mine == null)
                Text(
                  s.noCommunityYet,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                )
              else if (myIndex >= 0)
                _YourCommunity(
                  community: ranked![myIndex].$1,
                  points: ranked[myIndex].$2,
                  rank: myIndex + 1,
                )
              else if (ranked != null)
                // Past the end of the list: still yours, without a rank.
                StreamBuilder<Community?>(
                  stream: _watchMine(mine),
                  builder: (context, one) => one.data == null
                      ? const SizedBox(height: 72)
                      : _YourCommunity(community: one.data!),
                ),
              Gap.h12,
              OutlinedButton.icon(
                onPressed: () => openStartCommunity(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(s.startCommunity),
              ),
              Gap.h24,
              _Heading(s.allCommunities),
              Text(
                s.pointsExplain,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
              Gap.h8,
              if (ranked == null)
                const Padding(
                  padding: EdgeInsets.all(Gap.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (ranked.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.xl),
                  child: Text(
                    s.noCommunities,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                for (final (i, (c, points)) in ranked.indexed)
                  _CommunityRow(
                    community: c,
                    points: points,
                    rank: i + 1,
                    isMine: c.id == mine,
                    joining: _joining == c.id,
                    onJoin: _joining == null ? () => _join(c) : null,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.sm),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Yours, as a card that opens it.
class _YourCommunity extends StatelessWidget {
  const _YourCommunity({required this.community, this.points, this.rank});

  final Community community;
  final int? points;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = community;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: const BorderSide(color: AppColors.brandDim),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openCommunity(context, c.id),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              CommunityAvatar(id: c.id, name: c.name, size: 52),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        s.members(c.memberCount),
                        if (points != null) s.communityPoints(points!),
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (rank != null) ...[
                Gap.w8,
                Pill(
                  text: '#$rank',
                  color: AppColors.brand,
                  icon: Icons.emoji_events_outlined,
                ),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One community in the ranking.
class _CommunityRow extends StatelessWidget {
  const _CommunityRow({
    required this.community,
    required this.points,
    required this.rank,
    required this.isMine,
    required this.joining,
    required this.onJoin,
  });

  final Community community;
  final int points;
  final int rank;
  final bool isMine;
  final bool joining;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = community;
    final medal = switch (rank) {
      1 => const Color(0xFFFFC857),
      2 => const Color(0xFFC0CCD6),
      3 => const Color(0xFFD99A6C),
      _ => AppColors.textMuted,
    };
    return InkWell(
      onTap: () => openCommunity(context, c.id),
      borderRadius: Radii.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: tabularFigures,
                  color: medal,
                ),
              ),
            ),
            Gap.w8,
            CommunityAvatar(id: c.id, name: c.name, size: 44),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.members(c.memberCount)} · ${s.communityPoints(points)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Gap.w8,
            if (isMine)
              const Icon(Icons.check_circle_rounded, color: AppColors.brand)
            else if (joining)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              FilledButton.tonal(
                onPressed: onJoin,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  minimumSize: const Size(0, 34),
                ),
                child: Text(s.join),
              ),
          ],
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.couldNotLoad,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          Gap.h8,
          TextButton(onPressed: onRetry, child: Text(s.retry)),
        ],
      ),
    );
  }
}
