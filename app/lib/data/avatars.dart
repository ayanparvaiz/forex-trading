/// Which shelf of the picker an avatar sits on.
enum AvatarKind { animal, character }

/// One of the pickable profile avatars.
class Avatar {
  const Avatar(
    this.id,
    this.slug,
    this.bn,
    this.en, {
    this.kind = AvatarKind.animal,
  });

  /// Permanent number stored on the profile.
  ///
  /// This is an identity, not a position. Numbering by list index would look
  /// identical today and break the moment an avatar is removed or reordered:
  /// everyone below the gap would silently shift onto a different face without
  /// a single database row changing. Numbers here are assigned once, never
  /// reused, and never renumbered.
  final int id;

  /// Human-readable name for the same avatar, used in logs and tests where a
  /// bare number tells you nothing.
  final String slug;

  final String bn;
  final String en;
  final AvatarKind kind;

  /// Drawn by tool/make_avatars.py, one file per id.
  String get asset => 'assets/avatars/${id.toString().padLeft(2, '0')}.svg';

  String label(bool bangla) => bangla ? bn : en;
}

/// The avatars to choose from.
///
/// Drawn for this app rather than borrowed: sixteen animals, most with a
/// trading meaning — the bull and the bear, the whale, the turtle of the
/// Turtle Traders, the elephant that never forgets, the lucky cat of
/// shopkeepers — and eight original anime-style characters. Emoji looked different on every
/// phone and like nobody's in particular on any of them.
///
/// Where a subject survived from the emoji set it kept its number, so a
/// tiger is still a tiger. The ones that were retired handed their numbers to
/// new designs rather than leaving holes.
class Avatars {
  const Avatars._();

  static const all = <Avatar>[
    // Animals.
    Avatar(7, 'bull', 'ষাঁড়', 'Bull'),
    Avatar(24, 'bear', 'ভালুক', 'Bear'),
    Avatar(11, 'whale', 'তিমি', 'Whale'),
    Avatar(12, 'turtle', 'কচ্ছপ', 'Turtle'),
    Avatar(13, 'elephant', 'হাতি', 'Elephant'),
    Avatar(15, 'lucky-cat', 'লাকি ক্যাট', 'Lucky cat'),
    Avatar(1, 'owl', 'পেঁচা', 'Owl'),
    Avatar(2, 'tiger', 'বাঘ', 'Tiger'),
    Avatar(3, 'fox', 'শেয়াল', 'Fox'),
    Avatar(4, 'wolf', 'নেকড়ে', 'Wolf'),
    Avatar(5, 'lion', 'সিংহ', 'Lion'),
    Avatar(6, 'panda', 'পান্ডা', 'Panda'),
    Avatar(8, 'eagle', 'ঈগল', 'Eagle'),
    Avatar(9, 'shark', 'হাঙর', 'Shark'),
    Avatar(14, 'rabbit', 'খরগোশ', 'Rabbit'),
    Avatar(10, 'dragon', 'ড্রাগন', 'Dragon'),
    // Characters.
    Avatar(16, 'kira', 'কিরা', 'Kira', kind: AvatarKind.character),
    Avatar(17, 'ren', 'রেন', 'Ren', kind: AvatarKind.character),
    Avatar(18, 'kage', 'কাগে', 'Kage', kind: AvatarKind.character),
    Avatar(19, 'yuki', 'ইউকি', 'Yuki', kind: AvatarKind.character),
    Avatar(20, 'nova', 'নোভা', 'Nova', kind: AvatarKind.character),
    Avatar(21, 'rin', 'রিন', 'Rin', kind: AvatarKind.character),
    Avatar(22, 'zed', 'জেড', 'Zed', kind: AvatarKind.character),
    Avatar(23, 'taro', 'তারো', 'Taro', kind: AvatarKind.character),
  ];

  static const fallback = Avatar(1, 'owl', 'পেঁচা', 'Owl');

  static Iterable<Avatar> ofKind(AvatarKind kind) =>
      all.where((a) => a.kind == kind);

  /// Slugs from the emoji set, which some early profiles stored instead of a
  /// number. Each maps to the id it always had, whatever is drawn there now.
  static const _legacySlugs = {
    'koala': 7,
    'butterfly': 11,
    'octopus': 12,
    'dino': 13,
    'dolphin': 14,
    'cat': 15,
    'moon': 16,
    'bolt': 17,
    'fire': 18,
    'gem': 19,
    'rocket': 20,
  };

  /// Looks up by the stored number.
  ///
  /// An unknown number falls back rather than throwing: a profile written by a
  /// newer build than the one reading it should show a default face, not crash
  /// the leaderboard.
  static Avatar byId(int? id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return fallback;
  }

  static Avatar bySlug(String slug) {
    final legacy = _legacySlugs[slug];
    if (legacy != null) return byId(legacy);
    for (final a in all) {
      if (a.slug == slug) return a;
    }
    return fallback;
  }

  /// Reads whatever an old or new profile stored.
  ///
  /// Profiles written before avatars were numbered hold the slug, and those
  /// accounts already exist on installed devices. Accepting both costs three
  /// lines and avoids resetting real people's avatars.
  static Avatar from(Object? stored) => switch (stored) {
    final int id => byId(id),
    final String slug =>
      int.tryParse(slug) != null ? byId(int.parse(slug)) : bySlug(slug),
    _ => fallback,
  };
}
