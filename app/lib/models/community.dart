import 'trader.dart';

/// A group of traders with its own feed and its own chat room.
///
/// Anyone can start one and anyone can join one, but each person is in one
/// at a time. The one who started it is its admin.
class Community {
  const Community({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.memberCount,
    required this.createdAt,
    this.avatarId,
    this.locked = false,
    this.slowSeconds = 0,
    this.rules = const [],
    this.titles = const [],
  });

  static const nameMin = 3;

  /// What its admin asks of everyone in it: up to [rulesMax] lines of up to
  /// [ruleMax] letters each — the rules hold the same.
  static const rulesMax = 5;
  static const ruleMax = 120;
  static const nameMax = 60;
  static const descriptionMax = 200;

  final String id;
  final String name;
  final String description;

  /// Its picture, one of CommunityAvatars — or null for one from before
  /// pictures, which shows its initial.
  final int? avatarId;

  /// Locked by its admin: nobody new joins, and only the admin writes in its
  /// chat and its feed.
  final bool locked;

  /// Slow mode: each member writes in its room at most once this often, in
  /// seconds. 0 for off. The admin is never slowed.
  final int slowSeconds;

  /// The intervals the admin can choose from — the rules hold the same.
  static const slowModes = [0, 10, 30, 60, 300];

  /// Its rules, shown before joining. Empty when it has none.
  final List<String> rules;

  /// The months it was champion — on top when the month turned — as
  /// "2026-09", oldest first. Given by the worker alone.
  final List<String> titles;

  /// The admin's uid: whoever started it, until they hand it to someone
  /// else.
  final String createdBy;
  final int memberCount;
  final DateTime createdAt;

  /// Its chat room, in the rooms collection beside Global.
  String get roomId => roomIdFor(id);

  static String roomIdFor(String communityId) => 'c_$communityId';

  /// The community a room belongs to, or null for Global.
  static String? ofRoom(String roomId) =>
      roomId.startsWith('c_') ? roomId.substring(2) : null;

  /// The name as it is claimed: so "Dhaka Traders" and "dhaka traders" are
  /// one name, and spacing does not make a second.
  static String claimKey(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// The name as it is stored: trimmed, single-spaced.
  static String tidyName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// A month's champion, as the worker crowned it (worker/src/champion.js).
class Champion {
  const Champion({
    required this.month,
    required this.communityId,
    required this.name,
    required this.points,
  });

  /// "2026-09".
  final String month;

  /// Empty when nobody had points that month.
  final String communityId;
  final String name;
  final int points;
}

/// The first of the month [id] — "2026-09" — or null when it is not one.
DateTime? monthOf(String id) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(id);
  if (m == null) return null;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(m.group(1)!), month);
}

/// The month before the one [now] falls in, in Dhaka: the last one crowned.
String lastMonthId(DateTime now) {
  final d = now.toUtc().add(const Duration(hours: 6));
  final prev = DateTime.utc(d.year, d.month - 1);
  return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
}

/// Something a community's admin has planned — a chart review, a Q&A —
/// and who is going.
class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.createdBy,
    this.going = const {},
  });

  static const titleMin = 3;
  static const titleMax = 80;
  static const descriptionMax = 300;

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final String createdBy;
  final Set<String> going;

  /// Started, but within the last two hours: still worth showing.
  bool happeningAt(DateTime now) =>
      !startsAt.isAfter(now) &&
      now.difference(startsAt) < const Duration(hours: 2);
}

/// Someone in a community.
class CommunityMember {
  const CommunityMember({
    required this.uid,
    required this.username,
    required this.isAdmin,
    required this.joinedAt,
    this.isModerator = false,
  });

  /// How many moderators an admin may pick.
  static const maxModerators = 3;

  final String uid;
  final String username;
  final bool isAdmin;
  final DateTime joinedAt;

  /// Picked by the admin to help keep the room: pins messages, and takes
  /// down anyone's but the admin's.
  final bool isModerator;
}

/// A community's points, from where its members stand on the leaderboard:
/// someone at #1 of the top 50 is worth 50, at #50 worth 1, and anyone below
/// the board nothing. So a community rises by having members near the top,
/// not just many members.
Map<String, int> communityPoints(List<Trader> board, {int top = 50}) {
  final points = <String, int>{};
  for (final (i, t) in board.take(top).indexed) {
    final id = t.communityId;
    if (id == null) continue;
    points[id] = (points[id] ?? 0) + (top - i);
  }
  return points;
}

/// Communities best first: by points, then by size, then by name.
List<(Community, int)> rankCommunities(
  List<Community> communities,
  Map<String, int> points,
) {
  final ranked = [for (final c in communities) (c, points[c.id] ?? 0)];
  ranked.sort((a, b) {
    final p = b.$2.compareTo(a.$2);
    if (p != 0) return p;
    final m = b.$1.memberCount.compareTo(a.$1.memberCount);
    if (m != 0) return m;
    return a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
  });
  return ranked;
}
