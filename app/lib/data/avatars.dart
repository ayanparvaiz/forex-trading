/// One of the pickable profile avatars.
class Avatar {
  const Avatar(this.id, this.slug, this.emoji, this.bn, this.en);

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

  final String emoji;
  final String bn;
  final String en;

  String label(bool bangla) => bangla ? bn : en;
}

/// Twenty avatars to choose from at signup.
///
/// Emoji rather than illustrations: they render identically on every device,
/// add nothing to the bundle, cost no network round trip, and sidestep the
/// question of what a "default" face should look like.
class Avatars {
  const Avatars._();

  static const all = <Avatar>[
    Avatar(1, 'owl', '🦉', 'পেঁচা', 'Owl'),
    Avatar(2, 'tiger', '🐅', 'বাঘ', 'Tiger'),
    Avatar(3, 'fox', '🦊', 'শেয়াল', 'Fox'),
    Avatar(4, 'wolf', '🐺', 'নেকড়ে', 'Wolf'),
    Avatar(5, 'lion', '🦁', 'সিংহ', 'Lion'),
    Avatar(6, 'panda', '🐼', 'পান্ডা', 'Panda'),
    Avatar(7, 'koala', '🐨', 'কোয়ালা', 'Koala'),
    Avatar(8, 'eagle', '🦅', 'ঈগল', 'Eagle'),
    Avatar(9, 'shark', '🦈', 'হাঙর', 'Shark'),
    Avatar(10, 'dragon', '🐉', 'ড্রাগন', 'Dragon'),
    Avatar(11, 'butterfly', '🦋', 'প্রজাপতি', 'Butterfly'),
    Avatar(12, 'octopus', '🐙', 'অক্টোপাস', 'Octopus'),
    Avatar(13, 'dino', '🦖', 'ডাইনোসর', 'Dino'),
    Avatar(14, 'dolphin', '🐬', 'ডলফিন', 'Dolphin'),
    Avatar(15, 'cat', '🐈‍⬛', 'বিড়াল', 'Cat'),
    Avatar(16, 'moon', '🌙', 'চাঁদ', 'Moon'),
    Avatar(17, 'bolt', '⚡', 'বজ্র', 'Bolt'),
    Avatar(18, 'fire', '🔥', 'আগুন', 'Fire'),
    Avatar(19, 'gem', '💎', 'হীরা', 'Gem'),
    Avatar(20, 'rocket', '🚀', 'রকেট', 'Rocket'),
  ];

  static const fallback = Avatar(1, 'owl', '🦉', 'পেঁচা', 'Owl');

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
