import 'dart:async';

import '../models/trader.dart';
import 'community_repository.dart';

/// Why someone is where they are in search.
enum PersonReason {
  /// You are connected.
  connected,

  /// Someone you are connected to is connected to them.
  mutual,

  /// On the leaderboard.
  leaderboard,

  /// Found by the server, with nothing else tying them to you.
  match,
}

/// One person in search, and why.
class PersonHit {
  const PersonHit({
    required this.trader,
    required this.reason,
    this.mutualCount = 0,
    this.rank,
  });

  final Trader trader;
  final PersonReason reason;

  /// For [PersonReason.mutual]: how many of your connections know them.
  final int mutualCount;

  /// Their place on the leaderboard, when it is in the top 50.
  final int? rank;

  String get username => trader.id;
}

/// What search already knows before it asks the server: the people around
/// you. It is also where a name can match anywhere — Firestore only matches
/// the start of a field, but these few are on the phone already.
class PeoplePool {
  const PeoplePool({
    this.connections = const [],
    this.mutual = const {},
    this.leaderboard = const [],
  });

  static const empty = PeoplePool();

  final List<Trader> connections;

  /// People your connections are connected to, with how many of them.
  final Map<String, (Trader, int)> mutual;

  /// The board, best first.
  final List<Trader> leaderboard;

  int? rankOf(String username) {
    final i = leaderboard.indexWhere((t) => t.id == username);
    return i < 0 ? null : i + 1;
  }

  /// Everyone here once, each under the strongest reason they have.
  List<PersonHit> get everyone {
    final seen = <String>{};
    return [
      for (final t in connections)
        if (seen.add(t.id))
          PersonHit(
            trader: t,
            reason: PersonReason.connected,
            rank: rankOf(t.id),
          ),
      for (final (t, n) in mutual.values)
        if (seen.add(t.id))
          PersonHit(
            trader: t,
            reason: PersonReason.mutual,
            mutualCount: n,
            rank: rankOf(t.id),
          ),
      for (final (i, t) in leaderboard.indexed)
        if (seen.add(t.id))
          PersonHit(trader: t, reason: PersonReason.leaderboard, rank: i + 1),
    ];
  }
}

int _tier(PersonReason r) => switch (r) {
  PersonReason.connected => 0,
  PersonReason.mutual => 1,
  PersonReason.leaderboard => 2,
  PersonReason.match => 3,
};

/// Closer people first; among the mutual, more mutual first; then by rank.
int _byCloseness(PersonHit a, PersonHit b) {
  final t = _tier(a.reason).compareTo(_tier(b.reason));
  if (t != 0) return t;
  final m = b.mutualCount.compareTo(a.mutualCount);
  if (m != 0) return m;
  return (a.rank ?? 1 << 20).compareTo(b.rank ?? 1 << 20);
}

/// With nothing typed: the people around you, closest first.
List<PersonHit> suggestPeople(
  PeoplePool pool, {
  required String me,
  Set<String> exclude = const {},
  int limit = 12,
}) {
  final hits = [
    for (final h in pool.everyone)
      if (h.username != me && !exclude.contains(h.username)) h,
  ]..sort(_byCloseness);
  return hits.take(limit).toList();
}

/// How well [t] matches [q]: 0 for a start (of the username, the name, or
/// any word in it), 1 for anywhere else, null for not at all.
int? matchStrength(Trader t, String q) {
  if (q.isEmpty) return null;
  final name = t.name.toLowerCase();
  if (t.id.startsWith(q) || name.startsWith(q)) return 0;
  if (name.split(RegExp(r'\s+')).any((w) => w.startsWith(q))) return 0;
  if (t.id.contains(q) || name.contains(q)) return 1;
  return null;
}

/// Results for [query]: the people around you who match, closest first and
/// better matches first within that — then whoever else the server found.
List<PersonHit> rankPeople(
  String query,
  PeoplePool pool,
  List<Trader> server, {
  required String me,
  Set<String> exclude = const {},
  int limit = 20,
}) {
  final q = CommunityRepository.normaliseQuery(query);
  if (q.isEmpty) return const [];
  bool keep(String username) => username != me && !exclude.contains(username);

  final near =
      <(PersonHit, int)>[
        for (final h in pool.everyone)
          if (keep(h.username))
            if (matchStrength(h.trader, q) case final int strength)
              (h, strength),
      ]..sort((a, b) {
        final s = a.$2.compareTo(b.$2);
        return s != 0 ? s : _byCloseness(a.$1, b.$1);
      });

  final listed = {for (final (h, _) in near) h.username};
  final far = [
    for (final t in server)
      if (keep(t.id) && listed.add(t.id))
        PersonHit(
          trader: t,
          reason: PersonReason.match,
          rank: pool.rankOf(t.id),
        ),
  ];
  return [for (final (h, _) in near) h, ...far].take(limit).toList();
}

/// Gathers the people around [me]: my connections, a few of theirs, and the
/// board. About ten reads; fewer when there is less to know.
Future<PeoplePool> loadPeoplePool(
  CommunityRepository repository,
  String me, {
  int friendsToAsk = 8,
}) async {
  final connections = await repository
      .connectionsOf(me, limit: 50)
      .then((p) => p.items)
      .catchError((Object _) => <Trader>[]);
  final direct = {me, for (final c in connections) c.id};

  final theirs = await Future.wait([
    for (final c in connections.take(friendsToAsk))
      repository
          .connectionsOf(c.id, limit: 20)
          .then((p) => p.items)
          .catchError((Object _) => <Trader>[]),
  ]);
  final mutual = <String, (Trader, int)>{};
  for (final list in theirs) {
    for (final t in list) {
      if (direct.contains(t.id)) continue;
      final (_, n) = mutual[t.id] ?? (t, 0);
      mutual[t.id] = (t, n + 1);
    }
  }

  final board = await repository
      .watchLeaderboard(limit: CommunityRepository.leaderboardLimit)
      .first
      .timeout(const Duration(seconds: 8))
      .catchError((Object _) => <Trader>[]);

  return PeoplePool(
    connections: connections,
    mutual: mutual,
    leaderboard: board,
  );
}
