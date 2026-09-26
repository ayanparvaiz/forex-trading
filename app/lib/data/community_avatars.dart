/// Which shelf of the picker a community picture sits on.
enum CommunityAvatarTopic { market, discipline, nature, emblem }

/// One of the pictures a community can have.
class CommunityAvatar {
  const CommunityAvatar(this.id, this.slug, this.bn, this.en, this.topic);

  /// Permanent number stored on the community. Assigned once, never reused
  /// and never renumbered — see Avatar.id for why.
  final int id;
  final String slug;
  final String bn;
  final String en;
  final CommunityAvatarTopic topic;

  /// Drawn by tool/make_community_avatars.py, one file per id.
  String get asset =>
      'assets/community_avatars/${id.toString().padLeft(2, '0')}.svg';

  String label(bool bangla) => bangla ? bn : en;
}

/// The pictures to choose from: badges, not faces, so a community never
/// looks like a person. Seven on each of four topics.
class CommunityAvatars {
  const CommunityAvatars._();

  static const all = <CommunityAvatar>[
    // The market.
    CommunityAvatar(1, 'bull', 'ষাঁড়', 'Bull', CommunityAvatarTopic.market),
    CommunityAvatar(2, 'bear', 'ভালুক', 'Bear', CommunityAvatarTopic.market),
    CommunityAvatar(
      3,
      'candles',
      'ক্যান্ডেল',
      'Candles',
      CommunityAvatarTopic.market,
    ),
    CommunityAvatar(4, 'chart', 'চার্ট', 'Chart', CommunityAvatarTopic.market),
    CommunityAvatar(5, 'coins', 'কয়েন', 'Coins', CommunityAvatarTopic.market),
    CommunityAvatar(6, 'globe', 'পৃথিবী', 'Globe', CommunityAvatarTopic.market),
    CommunityAvatar(7, 'bell', 'ঘণ্টা', 'Bell', CommunityAvatarTopic.market),
    // Discipline.
    CommunityAvatar(
      8,
      'target',
      'লক্ষ্য',
      'Target',
      CommunityAvatarTopic.discipline,
    ),
    CommunityAvatar(
      9,
      'shield',
      'ঢাল',
      'Shield',
      CommunityAvatarTopic.discipline,
    ),
    CommunityAvatar(
      10,
      'knight',
      'ঘোড়া',
      'Knight',
      CommunityAvatarTopic.discipline,
    ),
    CommunityAvatar(
      11,
      'compass',
      'কম্পাস',
      'Compass',
      CommunityAvatarTopic.discipline,
    ),
    CommunityAvatar(
      12,
      'hourglass',
      'বালিঘড়ি',
      'Hourglass',
      CommunityAvatarTopic.discipline,
    ),
    CommunityAvatar(
      13,
      'scale',
      'দাঁড়িপাল্লা',
      'Scale',
      CommunityAvatarTopic.discipline,
    ),
    CommunityAvatar(14, 'key', 'চাবি', 'Key', CommunityAvatarTopic.discipline),
    // Nature.
    CommunityAvatar(
      15,
      'sunrise',
      'সূর্যোদয়',
      'Sunrise',
      CommunityAvatarTopic.nature,
    ),
    CommunityAvatar(16, 'moon', 'চাঁদ', 'Moon', CommunityAvatarTopic.nature),
    CommunityAvatar(
      17,
      'mountain',
      'পাহাড়',
      'Mountain',
      CommunityAvatarTopic.nature,
    ),
    CommunityAvatar(18, 'wave', 'ঢেউ', 'Wave', CommunityAvatarTopic.nature),
    CommunityAvatar(19, 'bolt', 'বিদ্যুৎ', 'Bolt', CommunityAvatarTopic.nature),
    CommunityAvatar(20, 'flame', 'আগুন', 'Flame', CommunityAvatarTopic.nature),
    CommunityAvatar(
      21,
      'shapla',
      'শাপলা',
      'Water lily',
      CommunityAvatarTopic.nature,
    ),
    // Emblems.
    CommunityAvatar(22, 'crown', 'মুকুট', 'Crown', CommunityAvatarTopic.emblem),
    CommunityAvatar(
      23,
      'trophy',
      'ট্রফি',
      'Trophy',
      CommunityAvatarTopic.emblem,
    ),
    CommunityAvatar(
      24,
      'diamond',
      'হীরা',
      'Diamond',
      CommunityAvatarTopic.emblem,
    ),
    CommunityAvatar(
      25,
      'anchor',
      'নোঙর',
      'Anchor',
      CommunityAvatarTopic.emblem,
    ),
    CommunityAvatar(
      26,
      'rocket',
      'রকেট',
      'Rocket',
      CommunityAvatarTopic.emblem,
    ),
    CommunityAvatar(27, 'star', 'তারা', 'Star', CommunityAvatarTopic.emblem),
    CommunityAvatar(28, 'flag', 'পতাকা', 'Flag', CommunityAvatarTopic.emblem),
  ];

  static const first = 1;
  static const last = 28;

  static Iterable<CommunityAvatar> ofTopic(CommunityAvatarTopic topic) =>
      all.where((a) => a.topic == topic);

  /// The picture stored as [id], or null — a community from before pictures,
  /// or one written by a newer build, shows its initial instead.
  static CommunityAvatar? byId(int? id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
