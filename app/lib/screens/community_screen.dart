import 'dart:async';

import 'package:flutter/material.dart';

import '../data/account_scope.dart';
import '../data/avatars.dart';
import '../data/community_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/notification_repository.dart';
import '../data/one_time_notice.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/app_notification.dart';
import '../models/post_comment.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/paged_list.dart';
import 'post_comments_sheet.dart';
import 'post_composer_sheet.dart';
import 'profile_screen.dart';

/// Leaderboard and shared journal feed.
///
/// The leaderboard ranks on discipline, and shows total R beside it without
/// ranking on it. The top trader in the sample data is down on the year; the
/// most profitable one is fourth. That contrast is the lesson, and it is why
/// the ranking rule is stated in plain text at the top of the list rather than
/// left for anyone to infer.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  /// Bumped after posting, to rebuild the feed from the top so the new post is
  /// there rather than waiting for a pull-to-refresh nobody thinks to do.
  int _feedVersion = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// The signed-in trader as a leaderboard row, built from their live numbers.
  Trader? _you(BuildContext context) {
    final profile = context.session.profile;
    if (profile == null) return null;

    // The same formula the worker writes with, over the same trades — so this
    // row is what the worker is about to store, shown before it has.
    final stats = AccountScope.of(context).leaderboardStats;

    return Trader(
      id: profile.username,
      name: profile.displayName,
      avatarEmoji: Avatars.byId(profile.avatarId).emoji,
      disciplineScore: stats.disciplineScore,
      badgePoints: stats.badgePoints,
      totalR: stats.totalR,
      tradeCount: stats.tradeCount,
      winRate: stats.winRate,
      journalStreak: stats.journalStreak,
      cohort: profile.cohort,
      isYou: true,
    );
  }

  /// Opens the composer, then shows the result where it landed.
  ///
  /// Posting from the leaderboard used to be impossible — the only compose
  /// button lived on the feed tab, so the question "where do I post?" had no
  /// answer on the screen half the people were looking at. It sits in the app
  /// bar now, above the tabs, because it belongs to the section rather than to
  /// one of its two lists.
  Future<void> _compose(
    CommunityRepository repository, {
    RankShare? rank,
  }) async {
    final posted = await showPostComposer(
      context,
      repository: repository,
      rank: rank,
    );
    if (!mounted || !posted) return;

    setState(() => _feedVersion++);
    // Land on the feed whichever tab it was written from. A post you cannot
    // see is indistinguishable from one that failed.
    _tabs.animateTo(1);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.s.posted)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final language = context.session.language;

    final repository = buildCommunityRepository(
      language,
      viewerUid: context.session.uid,
    );
    final you = _you(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navCommunity),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Gap.lg),
            child: FilledButton.icon(
              onPressed: () => _compose(repository),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(s.newPost),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.brand,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: AppColors.border,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            Tab(text: s.leaderboard),
            Tab(text: s.feed),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _Leaderboard(
            s: s,
            repository: repository,
            you: you,
            onShareRank: (share) => _compose(repository, rank: share),
          ),
          _Feed(s: s, repository: repository, version: _feedVersion),
        ],
      ),
    );
  }
}

class _Leaderboard extends StatefulWidget {
  const _Leaderboard({
    required this.s,
    required this.repository,
    required this.you,
    required this.onShareRank,
  });

  final Strings s;
  final CommunityRepository repository;
  final Trader? you;
  final ValueChanged<RankShare> onShareRank;

  @override
  State<_Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<_Leaderboard> {
  late Stream<List<Trader>> _board = widget.repository.watchLeaderboard();

  @override
  void didUpdateWidget(_Leaderboard old) {
    super.didUpdateWidget(old);
    // The screen above rebuilds every second with the market tick and hands
    // down a fresh repository each time. Resubscribing on every one of those
    // would open a new Firestore listener a second. Only a language change
    // alters what the board says — the cohort labels come back translated.
    if (old.s.lang != widget.s.lang) {
      _board = widget.repository.watchLeaderboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final you = widget.you;

    return StreamBuilder<List<Trader>>(
      stream: _board,
      builder: (context, snapshot) {
        // The signed-in trader's own numbers are swapped in wherever their row
        // lands. They are computed here with the worker's formula, so they
        // are what the worker is about to write — just sooner.
        final rows = [
          for (final t in snapshot.data ?? const <Trader>[])
            if (you != null && t.id == you.id) you else t,
        ];

        // Changes whenever anyone on the board moves, which is exactly when
        // the pinned position below may have changed too.
        final signature = Object.hashAll([
          for (final t in rows) Object.hash(t.id, t.disciplineScore),
        ]);

        return Column(
          children: [
            Expanded(child: _list(context, snapshot, rows)),
            if (you != null)
              _YourRankBar(
                you: you,
                s: s,
                repository: widget.repository,
                onShare: widget.onShareRank,
                boardSignature: signature,
              ),
          ],
        );
      },
    );
  }

  Widget _list(
    BuildContext context,
    AsyncSnapshot<List<Trader>> snapshot,
    List<Trader> rows,
  ) {
    final s = widget.s;

    Widget? status;
    if (snapshot.hasError) {
      debugPrint('leaderboard stream failed: ${snapshot.error}');
      status = Text(
        s.couldNotLoad,
        style: const TextStyle(color: AppColors.textMuted),
      );
    } else if (!snapshot.hasData) {
      status = const CircularProgressIndicator(
        strokeWidth: 2.4,
        color: AppColors.brand,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
      itemCount: status == null ? rows.length + 1 : 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: _RankingExplainer(s: s),
          );
        }
        if (status != null) {
          return Padding(
            padding: const EdgeInsets.only(top: Gap.xl),
            child: Center(child: status),
          );
        }
        return _LeaderboardRow(
          rank: i,
          trader: rows[i - 1],
          s: s,
          repository: widget.repository,
        );
      },
    );
  }
}

/// The signed-in trader's own position, pinned below the list.
///
/// The board stops at fifty, so most people will never scroll to their own row
/// — and the one position anybody actually cares about is their own. Keeping it
/// fixed means it is answered before the list is even read.
class _YourRankBar extends StatefulWidget {
  const _YourRankBar({
    required this.you,
    required this.s,
    required this.repository,
    required this.onShare,
    required this.boardSignature,
  });

  final Trader you;
  final Strings s;
  final CommunityRepository repository;
  final ValueChanged<RankShare> onShare;

  /// Changes whenever someone on the live board moves.
  ///
  /// A position is relative: yours changes when somebody else passes you, even
  /// though nothing about your own score did. The rank is an aggregate count,
  /// which Firestore cannot stream, so it is asked again each time the board
  /// that it is relative to changes.
  final int boardSignature;

  @override
  State<_YourRankBar> createState() => _YourRankBarState();
}

class _YourRankBarState extends State<_YourRankBar> {
  int? _rank;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_YourRankBar old) {
    super.didUpdateWidget(old);
    // Your score moved, or somebody else's did — either can move you.
    if (old.you.disciplineScore != widget.you.disciplineScore ||
        old.boardSignature != widget.boardSignature) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final rank = await widget.repository.rankOf(widget.you.id);
      if (mounted) setState(() => _rank = rank);
    } catch (error) {
      debugPrint('rank lookup failed: $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final rank = _rank;
    final inList = rank != null && rank <= CommunityRepository.leaderboardLimit;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: _failed
                    ? const Icon(
                        Icons.cloud_off_outlined,
                        size: 16,
                        color: AppColors.textMuted,
                      )
                    : rank == null
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textMuted,
                        ),
                      )
                    : Text(
                        '#$rank',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          fontFeatures: tabularFigures,
                          color: AppColors.brand,
                        ),
                      ),
              ),
              Text(
                widget.you.avatarEmoji,
                style: const TextStyle(fontSize: 22),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.yourPosition,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      // Only say "outside the list" once the rank is known —
                      // guessing while it loads would flash the wrong message.
                      rank == null || inList
                          ? s.topN(CommunityRepository.leaderboardLimit)
                          : s.outsideTop,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${widget.you.badge.tier.emoji} '
                '${widget.you.disciplineScore.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: tabularFigures,
                  color: AppColors.discipline,
                ),
              ),
              Gap.w4,
              // Only offered once the rank has actually come back. Sharing a
              // position the app is still looking up would post a number
              // nobody has seen, including its author.
              IconButton(
                onPressed: rank == null
                    ? null
                    : () => widget.onShare(
                        RankShare(
                          rank: rank,
                          score: widget.you.disciplineScore,
                          badgeEmoji: widget.you.badge.tier.emoji,
                        ),
                      ),
                icon: const Icon(Icons.ios_share, size: 19),
                color: AppColors.brand,
                disabledColor: AppColors.textMuted,
                visualDensity: VisualDensity.compact,
                tooltip: s.shareYourRank,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Why the list is ordered the way it is, stated rather than left to infer.
///
/// Said in full once, on the first visit after install, and collapsed to a
/// single line once it has been read. The rule is the whole point of the
/// screen, so it is never removed — but a paragraph that reprints itself above
/// the list every single time is one people learn to scroll past, and it costs
/// four rows of a fifty-row board to do it.
///
/// The collapsed line reopens on tap, because "I dismissed it and now I cannot
/// find out why I am ranked here" is a worse outcome than the paragraph.
class _RankingExplainer extends StatefulWidget {
  const _RankingExplainer({required this.s});

  final Strings s;

  @override
  State<_RankingExplainer> createState() => _RankingExplainerState();
}

class _RankingExplainerState extends State<_RankingExplainer> {
  final _notice = OneTimeNotice('leaderboard.ranking');

  /// Starts collapsed, which is what a returning reader sees. The flag resolves
  /// within a frame or two, so a first-time reader watches it open rather than
  /// watching a full panel shrink — a reveal reads better than a retraction.
  bool _read = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _notice.isDismissed().then((read) {
      if (mounted) setState(() => _read = read);
    });
  }

  Future<void> _markRead() async {
    setState(() {
      _read = true;
      _expanded = false;
    });
    await _notice.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final open = !_read || _expanded;

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: open ? _full(s) : _collapsed(s),
    );
  }

  Widget _full(Strings s) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: AppColors.disciplineDim,
        borderRadius: Radii.tile,
        border: Border.all(color: AppColors.discipline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppColors.discipline,
              ),
              Gap.w12,
              Expanded(
                child: Text(
                  s.leaderboardExplainer,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          Gap.h8,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _read
                  ? () => setState(() => _expanded = false)
                  : _markRead,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.discipline,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              ),
              child: Text(
                _read ? s.hide : s.gotIt,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collapsed(Strings s) {
    return InkWell(
      onTap: () => setState(() => _expanded = true),
      borderRadius: Radii.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 14,
              color: AppColors.discipline,
            ),
            Gap.w8,
            Expanded(
              child: Text(
                s.rankedByDiscipline,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.trader,
    required this.s,
    required this.repository,
  });

  final int rank;
  final Trader trader;
  final Strings s;
  final CommunityRepository repository;

  Color get _scoreColor {
    if (trader.disciplineScore >= 75) return AppColors.discipline;
    if (trader.disciplineScore >= 50) return AppColors.warning;
    return AppColors.loss;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openProfile(context, trader.id, repository),
      borderRadius: Radii.tile,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          color: trader.isYou ? AppColors.brandDim : AppColors.surface,
          borderRadius: Radii.tile,
          border: Border.all(
            color: trader.isYou ? AppColors.brand : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: tabularFigures,
                  color: rank <= 3
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
            Text(trader.avatarEmoji, style: const TextStyle(fontSize: 22)),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          trader.isYou ? s.you : trader.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Gap.w4,
                      Text(
                        '${trader.badge.tier.emoji}'
                        '${trader.badge.tier.isTop ? trader.badge.level : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  Gap.h4,
                  Row(
                    children: [
                      Text(
                        s.tradeCount(trader.tradeCount),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Text(
                        ' · ',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      // Profit is shown, never ranked on.
                      Text(
                        rMultiple(trader.totalR),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFeatures: tabularFigures,
                          color: AppColors.forValue(trader.totalR),
                        ),
                      ),
                      if (trader.journalStreak > 0) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        Text(
                          '🔥${trader.journalStreak}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trader.disciplineScore.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    fontFeatures: tabularFigures,
                    color: _scoreColor,
                  ),
                ),
                Text(
                  s.gradeFor(trader.disciplineScore),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
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

class _Feed extends StatefulWidget {
  const _Feed({
    required this.s,
    required this.repository,
    required this.version,
  });

  final Strings s;
  final CommunityRepository repository;

  /// Changes when something has been posted, which rebuilds the list from the
  /// first page so the new post is at the top where its author expects it.
  final int version;

  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> {
  /// When the list on screen was loaded. Posts after this are "new".
  DateTime _loadedAt = DateTime.now();
  late Stream<int> _newPosts = widget.repository.watchNewPostCount(_loadedAt);

  /// Bumped when the reader asks for the new posts.
  int _refreshes = 0;

  @override
  void didUpdateWidget(_Feed old) {
    super.didUpdateWidget(old);
    // Held across rebuilds for the same reason as the leaderboard stream: the
    // parent rebuilds every second, and a new listener each time would cost a
    // read a second for nothing. A post of your own or a language change is
    // a real reload, so those start the window again.
    if (old.version != widget.version || old.s.lang != widget.s.lang) {
      _restartWindow();
    }
  }

  void _restartWindow() {
    _loadedAt = DateTime.now();
    _newPosts = widget.repository.watchNewPostCount(_loadedAt);
  }

  void _showNewPosts() {
    setState(() {
      _refreshes++;
      _restartWindow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;

    return Stack(
      children: [
        PagedListView<FeedPost>(
          key: ValueKey('${s.lang}-${widget.version}-$_refreshes'),
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
          pageSize: 6,
          fetch: widget.repository.feed,
          itemBuilder: (context, post, _) => Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: _FeedCard(post: post, s: s, repository: widget.repository),
          ),
        ),
        Positioned(
          top: Gap.sm,
          left: 0,
          right: 0,
          child: StreamBuilder<int>(
            stream: _newPosts,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: count == 0
                    ? const SizedBox.shrink()
                    : Center(
                        key: const ValueKey('pill'),
                        child: _NewPostsPill(
                          text: s.newPostsCount(count),
                          onTap: _showNewPosts,
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NewPostsPill extends StatelessWidget {
  const _NewPostsPill({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand,
      borderRadius: Radii.pill,
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.pill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_upward, size: 15, color: Colors.white),
              Gap.w4,
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.post,
    required this.s,
    required this.repository,
  });

  final FeedPost post;
  final Strings s;
  final CommunityRepository repository;

  bool get _isRank => post.kind == PostKind.rank;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => openProfile(context, post.author.id, repository),
                child: Text(
                  post.author.avatarEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          openProfile(context, post.author.id, repository),
                      child: Text(
                        post.author.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _isRank
                          ? s.timeAgo(post.postedAt)
                          : '${post.symbol} · ${s.timeAgo(post.postedAt)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _isRank
                  ? Text(
                      '#${post.rank}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFeatures: tabularFigures,
                        color: AppColors.discipline,
                      ),
                    )
                  : Text(
                      rMultiple(post.rMultiple),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFeatures: tabularFigures,
                        color: AppColors.forValue(post.rMultiple),
                      ),
                    ),
            ],
          ),
          Gap.h12,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: Radii.tile,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A rank post has no trade behind it, so there is no reasoning
                // to show — only the line about how the author got there.
                if (!_isRank) ...[
                  Text(
                    s.whyITookIt,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Gap.h4,
                  Text(
                    post.reason,
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                  Gap.h12,
                ],
                Text(
                  _isRank ? s.howYouGotHere : s.whatILearned,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: post.followedRules
                        ? AppColors.brand
                        : AppColors.warning,
                  ),
                ),
                Gap.h4,
                Text(
                  post.lesson,
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
          Gap.h12,
          Row(
            children: [
              if (_isRank)
                Pill(
                  text:
                      '${s.discipline} '
                      '${(post.disciplineScore ?? 0).toStringAsFixed(0)}',
                  color: AppColors.discipline,
                  icon: Icons.shield_outlined,
                  dense: true,
                )
              else
                Pill(
                  text: post.followedRules ? s.followedRules : s.brokeRules,
                  color: post.followedRules ? AppColors.profit : AppColors.loss,
                  icon: post.followedRules
                      ? Icons.verified_outlined
                      : Icons.error_outline,
                  dense: true,
                ),
              const Spacer(),
              _PostActions(post: post, repository: repository),
            ],
          ),
        ],
      ),
    );
  }
}

/// Like and comment, with counts that move as other people act.
///
/// The counts come off a listener on the post document rather than the page
/// that loaded it, so a reaction from someone else appears without a refresh —
/// and the card does not have to refetch the whole feed to learn about it.
class _PostActions extends StatefulWidget {
  const _PostActions({required this.post, required this.repository});

  final FeedPost post;
  final CommunityRepository repository;

  @override
  State<_PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<_PostActions> {
  bool _liked = false;
  bool _busy = false;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState. Reading an InheritedWidget there is forbidden, and
    // because this runs inside an async call the resulting error vanishes into
    // an unhandled future — the like simply never loaded back, with nothing to
    // show for it. didChangeDependencies is the first place context is legal.
    if (_started) return;
    _started = true;
    _loadMyReaction();
  }

  Future<void> _loadMyReaction() async {
    final uid = context.session.uid;
    if (uid == null) return;

    // Building the card is the moment the post was seen, so reach is recorded
    // here rather than on a tap. Counted once per person, ever.
    unawaited(widget.repository.recordReach(widget.post.id, uid));

    final liked = await widget.repository.hasClapped(widget.post.id, uid);
    if (mounted) setState(() => _liked = liked);
  }

  Future<void> _toggle() async {
    final session = context.session;
    final me = session.profile;
    final uid = session.uid;
    if (me == null || uid == null || _busy) return;

    // Flipped before the write so the button answers immediately; the counter
    // beside it is the streamed truth and will correct this if it failed.
    setState(() {
      _liked = !_liked;
      _busy = true;
    });

    final liked = await widget.repository.toggleClap(widget.post.id, uid);

    // Only a new like is worth telling someone about. Un-liking is not news,
    // and notifying on every toggle would let one person spam a bell.
    if (liked) {
      final authorUid = await widget.repository.postAuthorUid(widget.post.id);
      if (authorUid != null) {
        await notificationRepository.notify(
          recipientUid: authorUid,
          kind: NotificationKind.clap,
          actorUid: uid,
          actorUsername: me.username,
          actorName: me.displayName,
          actorAvatarId: me.avatarId,
          postId: widget.post.id,
        );
      }
    }

    if (mounted) {
      setState(() {
        _liked = liked;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PostCounters>(
      stream: widget.repository.watchPost(widget.post.id),
      builder: (context, snapshot) {
        // Falls back to the numbers the page was loaded with, so the row never
        // flashes zeros while the listener connects.
        final counters =
            snapshot.data ??
            PostCounters(
              claps: widget.post.claps,
              commentCount: widget.post.commentCount,
              reach: widget.post.reach,
            );

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reach first, and deliberately quiet. It is how the feed decides
            // what a stranger sees, not a score to chase.
            //
            // Shown even at zero. Hiding it below a threshold meant a whole
            // feed of new posts showed none at all, which read as a missing
            // feature rather than an honest count.
            const Icon(
              Icons.visibility_outlined,
              size: 14,
              color: AppColors.textMuted,
            ),
            Gap.w4,
            Text(
              '${counters.reach}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                fontFeatures: tabularFigures,
              ),
            ),
            Gap.w12,
            InkWell(
              onTap: _toggle,
              borderRadius: Radii.pill,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _liked ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: _liked ? AppColors.loss : AppColors.textMuted,
                    ),
                    Gap.w4,
                    Text(
                      '${counters.claps}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _liked ? FontWeight.w700 : FontWeight.w400,
                        color: _liked ? AppColors.loss : AppColors.textMuted,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Gap.w8,
            InkWell(
              onTap: () => showPostComments(
                context,
                postId: widget.post.id,
                repository: widget.repository,
              ),
              borderRadius: Radii.pill,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mode_comment_outlined,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                    Gap.w4,
                    Text(
                      '${counters.commentCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
