import 'package:flutter/material.dart';

import '../data/community_repository.dart';
import '../data/notification_repository.dart';
import '../data/page.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/app_notification.dart';
import '../models/connection.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/paged_list.dart';
import '../widgets/avatar_image.dart';
import 'edit_profile_sheet.dart';

/// Opens [username]'s profile.
///
/// Every route into a profile goes through here, so recording the visit can
/// never be forgotten at one call site and remembered at another.
void openProfile(
  BuildContext context,
  String username,
  CommunityRepository repository,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProfileScreen(username: username, repository: repository),
    ),
  );
}

/// A trader's public page.
///
/// Opening someone's profile records a visit, which is why the visitor list
/// exists at all. Your own page shows who looked and what is waiting on you;
/// everyone else's shows the connect button instead. Visitors are private to
/// the person being visited — a list of who is watching whom, shown to
/// everyone, is a different and much worse product.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.username,
    required this.repository,
  });

  final String username;
  final CommunityRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Trader? _trader;
  ConnectionStatus _status = ConnectionStatus.none;
  int _connectionCount = 0;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;

  /// Rebuilt to force the paged lists to refetch after a connection changes.
  int _listVersion = 0;

  String? get _me => context.session.profile?.username;

  bool get _isSelf => _me == widget.username;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the profile.
  ///
  /// Everything here is wrapped. An await with no catch leaves the loading flag
  /// set and the screen spins forever on any failure — a refused query, a
  /// dropped connection — looking busy long after it gave up. That has already
  /// happened twice on this screen; it is not allowed to happen a third time.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final trader = await widget.repository.trader(widget.username);
      final count = await widget.repository.connectionCount(widget.username);

      final me = _me;
      var status = ConnectionStatus.none;
      if (me != null && me != widget.username) {
        status = await widget.repository.statusBetween(me, widget.username);
        // Opening the page is the visit. Recorded after the read so it never
        // shows the viewer their own arrival.
        await widget.repository.recordView(
          viewer: me,
          profileId: widget.username,
        );
      }

      if (!mounted) return;
      setState(() {
        _trader = trader;
        _status = status;
        _connectionCount = count;
        _loading = false;
      });
    } catch (error) {
      debugPrint('profile load failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// Tells [toUsername] what just happened.
  ///
  /// Addressed by uid because that is what the rules can verify; the username
  /// travels alongside only so the row can link back to a profile.
  Future<void> _notify(NotificationKind kind, String toUsername) async {
    final session = context.session;
    final me = session.profile;
    final myUid = session.uid;
    if (me == null || myUid == null) return;

    final theirUid = await widget.repository.uidFor(toUsername);
    if (theirUid == null) return;

    await notificationRepository.notify(
      recipientUid: theirUid,
      kind: kind,
      actorUid: myUid,
      actorUsername: me.username,
      actorName: me.displayName,
      actorAvatarId: me.avatarId,
    );
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _busy = true);

    try {
      await action();

      final me = _me;
      final status = me == null
          ? ConnectionStatus.none
          : await widget.repository.statusBetween(me, widget.username);
      final count = await widget.repository.connectionCount(widget.username);

      if (!mounted) return;
      setState(() {
        _status = status;
        _connectionCount = count;
        _busy = false;
        _listVersion++;
      });
    } catch (error) {
      debugPrint('profile action failed: $error');
      if (!mounted) return;
      // Clearing busy matters more than reporting: a stuck spinner on the
      // connect button makes the whole profile look broken.
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final trader = _trader;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.profile),
        actions: [
          if (_isSelf && _trader != null)
            TextButton.icon(
              onPressed: () async {
                // Re-read after saving, so the header shows what was stored
                // rather than what was typed.
                if (await showEditProfileSheet(context)) _load();
              },
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: Text(s.edit),
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            ),
          Gap.w8,
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.brand,
              ),
            )
          : trader == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _failed
                          ? Icons.cloud_off_outlined
                          : Icons.person_off_outlined,
                      size: 30,
                      color: AppColors.textMuted,
                    ),
                    Gap.h12,
                    Text(
                      _failed ? s.couldNotLoad : '@${widget.username}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    if (_failed) ...[
                      Gap.h12,
                      FilledButton(onPressed: _load, child: Text(s.retry)),
                    ],
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.md,
                Gap.lg,
                Gap.xxl,
              ),
              children: [
                _Header(trader: trader, s: s),
                Gap.h12,
                if (!_isSelf) ...[
                  _ConnectButton(
                    status: _status,
                    busy: _busy,
                    s: s,
                    onConnect: () => _act(() async {
                      await widget.repository.sendRequest(
                        from: _me!,
                        to: widget.username,
                      );
                      await _notify(
                        NotificationKind.connectionRequest,
                        widget.username,
                      );
                    }),
                    onAccept: () => _act(() async {
                      await widget.repository.acceptRequest(
                        me: _me!,
                        from: widget.username,
                      );
                      await _notify(
                        NotificationKind.connectionAccepted,
                        widget.username,
                      );
                    }),
                    onRemove: () => _act(
                      () => widget.repository.removeConnection(
                        me: _me!,
                        other: widget.username,
                      ),
                    ),
                  ),
                  Gap.h12,
                ],
                _StatsCard(
                  trader: trader,
                  connectionCount: _connectionCount,
                  s: s,
                ),
                Gap.h12,
                _BadgeCard(trader: trader, s: s),
                if (_isSelf) ...[
                  Gap.h12,
                  _PendingRequests(
                    key: ValueKey('pending-$_listVersion'),
                    username: widget.username,
                    repository: widget.repository,
                    s: s,
                    onNotify: _notify,
                    onChanged: () => _act(() async {}),
                  ),
                  Gap.h12,
                  _Viewers(
                    key: ValueKey('viewers-$_listVersion'),
                    username: widget.username,
                    repository: widget.repository,
                    s: s,
                  ),
                ],
                Gap.h12,
                _Connections(
                  key: ValueKey('connections-$_listVersion'),
                  username: widget.username,
                  repository: widget.repository,
                  s: s,
                  isSelf: _isSelf,
                ),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.trader, required this.s});

  final Trader trader;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.elevated,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AvatarImage(trader.avatarId, size: 64),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trader.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  '@${trader.id}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                Gap.h8,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(
                      text:
                          '${trader.badge.tier.emoji} '
                          '${trader.badge.label(s.isBangla)}',
                      color: AppColors.warning,
                      dense: true,
                    ),
                    Pill(
                      text: trader.cohort,
                      color: AppColors.brand,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({
    required this.status,
    required this.busy,
    required this.s,
    required this.onConnect,
    required this.onAccept,
    required this.onRemove,
  });

  final ConnectionStatus status;
  final bool busy;
  final Strings s;
  final VoidCallback onConnect;
  final VoidCallback onAccept;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.brand,
            ),
          ),
        ),
      );
    }

    return switch (status) {
      ConnectionStatus.none => FilledButton.icon(
        onPressed: onConnect,
        icon: const Icon(Icons.person_add_alt_1, size: 18),
        label: Text(s.connect),
      ),
      // An outgoing request is not a state to celebrate, so it reads as a
      // pending action you can take back rather than a success message.
      ConnectionStatus.pendingOutgoing => OutlinedButton.icon(
        onPressed: onRemove,
        icon: const Icon(Icons.schedule, size: 18),
        label: Text('${s.requestSent} · ${s.withdraw}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
        ),
      ),
      ConnectionStatus.pendingIncoming => Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check, size: 18),
              label: Text(s.accept),
            ),
          ),
          Gap.w12,
          Expanded(
            child: OutlinedButton(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(52),
                shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
              ),
              child: Text(s.decline),
            ),
          ),
        ],
      ),
      ConnectionStatus.connected => OutlinedButton.icon(
        onPressed: onRemove,
        icon: const Icon(Icons.how_to_reg, size: 18),
        label: Text('${s.connected} · ${s.disconnect}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand),
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
        ),
      ),
    };
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.trader,
    required this.connectionCount,
    required this.s,
  });

  final Trader trader;
  final int connectionCount;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: s.discipline,
                  value: trader.disciplineScore.toStringAsFixed(0),
                  hint: s.gradeFor(trader.disciplineScore),
                  valueColor: trader.disciplineScore >= 75
                      ? AppColors.discipline
                      : AppColors.warning,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.trades,
                  value: '${trader.tradeCount}',
                  hint:
                      '${(trader.winRate * 100).toStringAsFixed(0)}% '
                      '${s.winRate.toLowerCase()}',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.totalR,
                  value: rMultiple(trader.totalR),
                  valueColor: AppColors.forValue(trader.totalR),
                ),
              ),
            ],
          ),
          Gap.h16,
          const Divider(),
          Gap.h16,
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: s.connections,
                  value: '$connectionCount',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.badgePoints,
                  value: '${trader.badgePoints}',
                  valueColor: AppColors.warning,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: s.journalStreakLabel,
                  value: '🔥 ${trader.journalStreak}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.trader, required this.s});

  final Trader trader;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final rank = trader.badge;
    final next = rank.nextTier;

    return SectionCard(
      title: s.badge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(rank.tier.emoji, style: const TextStyle(fontSize: 32)),
              Gap.w12,
              Expanded(
                child: Text(
                  rank.label(s.isBangla),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Pill(
                text: '${rank.points} ${s.points}',
                color: AppColors.warning,
                dense: true,
              ),
            ],
          ),
          Gap.h12,
          ClipRRect(
            borderRadius: Radii.pill,
            child: LinearProgressIndicator(
              value: rank.progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.elevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.warning),
            ),
          ),
          Gap.h8,
          Text(
            next == null
                ? s.pointsToNext(
                    rank.pointsToNext,
                    '${rank.tier.label(s.isBangla)} ${rank.level + 1}',
                  )
                : s.pointsToNext(rank.pointsToNext, next.label(s.isBangla)),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A short paged list inside a card, for viewers / connections / requests.
class _PeopleCard extends StatelessWidget {
  const _PeopleCard({
    required this.title,
    required this.emptyLabel,
    required this.child,
  });

  final String title;
  final String emptyLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}

/// Lists a bounded number of people, with a "show more" that pages.
class _PeopleList<T> extends StatefulWidget {
  const _PeopleList({
    super.key,
    required this.fetch,
    required this.rowBuilder,
    required this.emptyLabel,
    this.pageSize = 5,
  });

  final PageFetcher<T> fetch;
  final Widget Function(BuildContext, T) rowBuilder;
  final String emptyLabel;
  final int pageSize;

  @override
  State<_PeopleList<T>> createState() => _PeopleListState<T>();
}

class _PeopleListState<T> extends State<_PeopleList<T>> {
  final _items = <T>[];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final page = await widget.fetch(cursor: _cursor, limit: widget.pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (error) {
      // Without this the spinner runs forever on any failure — a denied query,
      // a dropped connection — and the screen looks like it is still working
      // when it has already given up.
      debugPrint('people list failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Gap.lg),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    if (_failed && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 16,
              color: AppColors.textMuted,
            ),
            Gap.w8,
            Expanded(
              child: Text(
                context.s.couldNotLoad,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: _more,
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: Text(context.s.retry),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Text(
          widget.emptyLabel,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final item in _items) widget.rowBuilder(context, item),
        if (_hasMore)
          TextButton(
            onPressed: _loading ? null : _more,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              minimumSize: const Size.fromHeight(38),
            ),
            child: Text(context.s.isBangla ? 'আরও দেখুন' : 'Show more'),
          ),
      ],
    );
  }
}

/// One person, tappable through to their profile.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.trader,
    required this.repository,
    this.subtitle,
    this.trailing,
  });

  final Trader trader;
  final CommunityRepository repository;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return InkWell(
      onTap: () => openProfile(context, trader.id, repository),
      borderRadius: Radii.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            AvatarImage(trader.avatarId, size: 36),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trader.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle ??
                        '${trader.badge.tier.emoji} '
                            '${trader.badge.label(s.isBangla)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _PendingRequests extends StatelessWidget {
  const _PendingRequests({
    super.key,
    required this.username,
    required this.repository,
    required this.s,
    required this.onChanged,
    required this.onNotify,
  });

  final String username;
  final CommunityRepository repository;
  final Strings s;
  final VoidCallback onChanged;
  final Future<void> Function(NotificationKind, String) onNotify;

  @override
  Widget build(BuildContext context) {
    return _PeopleCard(
      title: s.pendingRequests,
      emptyLabel: s.noPendingRequests,
      child: _PeopleList<Trader>(
        fetch: ({Object? cursor, int limit = 5}) => repository
            .pendingRequestsFor(username, cursor: cursor, limit: limit),
        emptyLabel: s.noPendingRequests,
        rowBuilder: (context, trader) => _PersonRow(
          trader: trader,
          repository: repository,
          subtitle: s.wantsToConnect,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () async {
                  await repository.acceptRequest(me: username, from: trader.id);
                  await onNotify(
                    NotificationKind.connectionAccepted,
                    trader.id,
                  );
                  onChanged();
                },
                icon: const Icon(Icons.check_circle, size: 22),
                color: AppColors.profit,
                tooltip: s.accept,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () async {
                  await repository.removeConnection(
                    me: username,
                    other: trader.id,
                  );
                  onChanged();
                },
                icon: const Icon(Icons.cancel, size: 22),
                color: AppColors.textMuted,
                tooltip: s.decline,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Summary row for the visitor list: a count, and a tap to open it.
///
/// The list itself lives on its own screen. Inlining it would push the rest of
/// the profile off the page once anyone has more than a handful of visitors,
/// and the number is what people actually check.
class _Viewers extends StatefulWidget {
  const _Viewers({
    super.key,
    required this.username,
    required this.repository,
    required this.s,
  });

  final String username;
  final CommunityRepository repository;
  final Strings s;

  @override
  State<_Viewers> createState() => _ViewersState();
}

class _ViewersState extends State<_Viewers> {
  int? _count;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final count = await widget.repository.viewerCount(widget.username);
      if (mounted) setState(() => _count = count);
    } catch (error) {
      debugPrint('viewer count failed: $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final count = _count;

    return SectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: count == null || count == 0
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileViewersScreen(
                    username: widget.username,
                    repository: widget.repository,
                  ),
                ),
              ),
        borderRadius: Radii.card,
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 20,
                color: AppColors.discipline,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.profileViewers,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      s.viewersArePrivate,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_failed)
                TextButton(
                  onPressed: _load,
                  style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                  child: Text(s.retry),
                )
              else if (count == null)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textMuted,
                  ),
                )
              else ...[
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFeatures: tabularFigures,
                    color: AppColors.discipline,
                  ),
                ),
                if (count > 0) ...[
                  Gap.w4,
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The full visitor list, paged.
class ProfileViewersScreen extends StatelessWidget {
  const ProfileViewersScreen({
    super.key,
    required this.username,
    required this.repository,
  });

  final String username;
  final CommunityRepository repository;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      appBar: AppBar(title: Text(s.profileViewers)),
      body: PagedListView<ProfileView>(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        pageSize: 15,
        emptyLabel: s.noViewersYet,
        fetch: ({Object? cursor, int limit = 15}) =>
            repository.viewersOf(username, cursor: cursor, limit: limit),
        itemBuilder: (context, view, _) => FutureBuilder<Trader?>(
          future: repository.trader(view.viewer),
          builder: (context, snapshot) {
            final trader = snapshot.data;
            if (trader == null) return const SizedBox(height: 52);

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: Radii.tile,
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: _PersonRow(
                trader: trader,
                repository: repository,
                subtitle: s.timeAgo(view.viewedAt),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Connections extends StatelessWidget {
  const _Connections({
    super.key,
    required this.username,
    required this.repository,
    required this.s,
    required this.isSelf,
  });

  final String username;
  final CommunityRepository repository;
  final Strings s;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    return _PeopleCard(
      title: s.connections,
      emptyLabel: s.noConnectionsYet,
      child: _PeopleList<Trader>(
        fetch: ({Object? cursor, int limit = 5}) =>
            repository.connectionsOf(username, cursor: cursor, limit: limit),
        emptyLabel: isSelf ? s.noConnectionsYet : '—',
        rowBuilder: (context, trader) =>
            _PersonRow(trader: trader, repository: repository),
      ),
    );
  }
}
