import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/community_repository.dart';
import '../data/firestore_community_repository.dart';
import '../data/people_search.dart';
import '../data/recent_searches.dart';
import '../data/session_controller.dart';
import '../i18n/strings.dart';
import '../models/chat.dart';
import '../models/trader.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_image.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'post_screen.dart';
import 'profile_screen.dart';

/// Opens search.
Future<void> openSearch(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SearchScreen()));

/// Finding people, the way Facebook's search does it.
///
/// Before anything is typed: who you last opened from here, then people you
/// might be looking for — your connections, people they know, the board.
/// Typed: the people around you who match anywhere in their name come first,
/// then anyone else whose name or username starts with it, then a few of
/// their posts. Someone with a message you have not read opens to that chat;
/// anyone else, to their profile.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  CommunityRepository? _repository;
  RecentSearches? _recents;
  String _me = '';

  PeoplePool _pool = PeoplePool.empty;
  bool _poolLoaded = false;
  List<RecentPerson> _recent = const [];

  /// What the server found for the query now in the box.
  List<Trader> _server = const [];
  List<FeedPost> _posts = const [];
  bool _searching = false;
  Timer? _debounce;

  /// Bumped per search, so a slow answer never replaces a newer one.
  int _asked = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repository != null) return;
    final session = context.session;
    _me = session.profile?.username ?? '';
    final repository = buildCommunityRepository(
      session.language,
      viewerUid: session.uid,
    );
    _repository = repository;
    _recents = RecentSearches(owner: session.uid ?? _me);
    _recents!.load().then((r) {
      if (mounted) setState(() => _recent = r);
    });
    loadPeoplePool(repository, _me).then((pool) {
      if (!mounted) return;
      setState(() {
        _pool = pool;
        _poolLoaded = true;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Set<String> get _blocked =>
      InboxScope.read(context)?.blockedUsernames ?? const {};

  void _onChanged(String text) {
    _debounce?.cancel();
    final q = CommunityRepository.normaliseQuery(text);
    setState(() {
      if (q.isEmpty) {
        _server = const [];
        _posts = const [];
        _searching = false;
      } else {
        _searching = true;
      }
    });
    if (q.isEmpty) {
      _asked++;
      return;
    }
    // A keystroke at a time is a query at a time; wait for a pause.
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(q));
  }

  Future<void> _search(String q) async {
    final repository = _repository;
    if (repository == null) return;
    final ask = ++_asked;
    List<Trader> server;
    try {
      server = await repository.searchPeople(q);
    } catch (e) {
      debugPrint('search failed: $e');
      server = const [];
    }
    if (!mounted || ask != _asked) return;
    setState(() {
      _server = server;
      _searching = false;
    });

    // A few posts by the best matches, newest first.
    final top = rankPeople(
      q,
      _pool,
      server,
      me: _me,
      exclude: _blocked,
    ).take(3);
    final lists = await Future.wait([
      for (final h in top)
        repository
            .postsBy(h.username, limit: 2)
            .catchError((Object _) => <FeedPost>[]),
    ]);
    if (!mounted || ask != _asked) return;
    setState(() {
      _posts = [for (final l in lists) ...l]
        ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    });
  }

  /// Opens [person]: to the chat when they have written something you have
  /// not read, otherwise to their profile. Either way, remembered.
  Future<void> _open(RecentPerson person) async {
    final recents = _recents;
    if (recents != null) {
      recents.add(person).then((r) {
        if (mounted) setState(() => _recent = r);
      });
    }
    final unread = _unreadFrom(person.username);
    final inbox = InboxScope.read(context);
    final uid = context.session.uid;
    if (unread != null && inbox != null && uid != null) {
      await openChat(
        context,
        chatId: unread.id,
        otherUid: unread.otherUid(uid),
        otherUsername: person.username,
      );
      return;
    }
    openProfile(context, person.username, _repository!);
  }

  /// The conversation with [username], if it has messages you have not read.
  ChatThread? _unreadFrom(String username) {
    final inbox = InboxScope.read(context);
    if (inbox == null) return null;
    for (final t in inbox.threads) {
      if (t.otherUsername(_me) == username && t.unreadFor(inbox.uid) > 0) {
        return t;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // Rebuilt when a message arrives, so "new message" is current.
    InboxScope.of(context);
    final q = CommunityRepository.normaliseQuery(_query.text);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: s.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _query.clear();
                      _onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
          ),
        ),
        bottom: _searching
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.brand,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: q.isEmpty ? _suggestions(s) : _results(s, q),
    );
  }

  Widget _suggestions(Strings s) {
    final suggested = suggestPeople(_pool, me: _me, exclude: _blocked);
    final recent = [
      for (final p in _recent)
        if (!_blocked.contains(p.username)) p,
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xxl),
      children: [
        if (recent.isNotEmpty) ...[
          _Header(
            title: s.recentSearches,
            action: s.clearAll,
            onAction: () async {
              await _recents?.clear();
              if (mounted) setState(() => _recent = const []);
            },
          ),
          for (final p in recent)
            _PersonTile(
              name: p.name,
              username: p.username,
              avatarId: p.avatarId,
              line: _lineFor(s, p.username, null),
              unread: _unreadFrom(p.username) != null,
              onTap: () => _open(p),
              trailing: IconButton(
                onPressed: () async {
                  final r = await _recents?.remove(p.username);
                  if (mounted && r != null) setState(() => _recent = r);
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
        _Header(title: s.suggestedForYou),
        if (!_poolLoaded)
          const Padding(
            padding: EdgeInsets.all(Gap.xl),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.brand,
              ),
            ),
          )
        else if (suggested.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text(
              s.noSuggestionsYet,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final h in suggested) _hitTile(s, h),
      ],
    );
  }

  Widget _results(Strings s, String q) {
    final hits = rankPeople(q, _pool, _server, me: _me, exclude: _blocked);
    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xxl),
      children: [
        _Header(title: s.people),
        if (hits.isEmpty && !_searching)
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text(
              s.noOneFound(_query.text.trim()),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        for (final h in hits) _hitTile(s, h),
        if (_posts.isNotEmpty) ...[
          _Header(title: s.posts),
          for (final p in _posts)
            _PostTile(post: p, s: s, onTap: () => openPost(context, p.id)),
        ],
      ],
    );
  }

  Widget _hitTile(Strings s, PersonHit h) => _PersonTile(
    name: h.trader.name,
    username: h.username,
    avatarId: h.trader.avatarId,
    rank: h.rank,
    line: _lineFor(s, h.username, h),
    unread: _unreadFrom(h.username) != null,
    onTap: () => _open(RecentPerson.of(h.trader)),
  );

  /// The second line: news first, then why they are here.
  String _lineFor(Strings s, String username, PersonHit? h) {
    final unread = _unreadFrom(username);
    if (unread != null) {
      return s.newMessages(unread.unreadFor(InboxScope.read(context)!.uid));
    }
    final why = switch (h?.reason) {
      PersonReason.connected => s.connectedLabel,
      PersonReason.mutual => s.mutualConnections(h!.mutualCount),
      PersonReason.leaderboard => s.rankOnBoard(h!.rank ?? 0),
      _ => null,
    };
    return why == null ? '@$username' : '@$username · $why';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.sm, Gap.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.name,
    required this.username,
    required this.avatarId,
    required this.line,
    required this.unread,
    required this.onTap,
    this.rank,
    this.trailing,
  });

  final String name;
  final String username;
  final int avatarId;
  final String line;

  /// [line] is news: a message not read yet.
  final bool unread;
  final VoidCallback onTap;

  /// Their place on the board, shown only inside the top 50.
  final int? rank;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final r = rank;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 8, Gap.xs, 8),
        child: Row(
          children: [
            AvatarImage(avatarId, size: 46),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (r != null &&
                          r <= CommunityRepository.leaderboardLimit)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            r <= 3 ? '${['🥇', '🥈', '🥉'][r - 1]} #$r' : '#$r',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              fontFeatures: tabularFigures,
                              color: AppColors.discipline,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                      color: unread ? AppColors.profit : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            if (trailing == null) Gap.w12,
          ],
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.s, required this.onTap});

  final FeedPost post;
  final Strings s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rank = post.kind == PostKind.rank;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarImage(post.author.avatarId, size: 36),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        rank
                            ? '  #${post.rank}'
                            : '  ${post.symbol} ${rMultiple(post.rMultiple)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: rank
                              ? AppColors.discipline
                              : AppColors.forValue(post.rMultiple),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        s.timeAgo(post.postedAt),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    post.lesson,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
