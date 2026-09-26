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
  });

  static const nameMin = 3;
  static const nameMax = 60;
  static const descriptionMax = 200;

  final String id;
  final String name;
  final String description;

  /// Its picture, one of CommunityAvatars — or null for one from before
  /// pictures, which shows its initial.
  final int? avatarId;

  /// The founder's uid — the admin.
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

/// Someone in a community.
class CommunityMember {
  const CommunityMember({
    required this.uid,
    required this.username,
    required this.isAdmin,
    required this.joinedAt,
  });

  final String uid;
  final String username;
  final bool isAdmin;
  final DateTime joinedAt;
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
