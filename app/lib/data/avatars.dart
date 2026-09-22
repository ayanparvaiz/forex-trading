/// One of the pickable profile avatars.
class Avatar {
  const Avatar(this.id, this.emoji, this.bn, this.en);

  /// Stable key stored on the profile. Never changes, even if the art does.
  final String id;
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
    Avatar('owl', '🦉', 'পেঁচা', 'Owl'),
    Avatar('tiger', '🐅', 'বাঘ', 'Tiger'),
    Avatar('fox', '🦊', 'শেয়াল', 'Fox'),
    Avatar('wolf', '🐺', 'নেকড়ে', 'Wolf'),
    Avatar('lion', '🦁', 'সিংহ', 'Lion'),
    Avatar('panda', '🐼', 'পান্ডা', 'Panda'),
    Avatar('koala', '🐨', 'কোয়ালা', 'Koala'),
    Avatar('eagle', '🦅', 'ঈগল', 'Eagle'),
    Avatar('shark', '🦈', 'হাঙর', 'Shark'),
    Avatar('dragon', '🐉', 'ড্রাগন', 'Dragon'),
    Avatar('butterfly', '🦋', 'প্রজাপতি', 'Butterfly'),
    Avatar('octopus', '🐙', 'অক্টোপাস', 'Octopus'),
    Avatar('dino', '🦖', 'ডাইনোসর', 'Dino'),
    Avatar('dolphin', '🐬', 'ডলফিন', 'Dolphin'),
    Avatar('cat', '🐈‍⬛', 'বিড়াল', 'Cat'),
    Avatar('moon', '🌙', 'চাঁদ', 'Moon'),
    Avatar('bolt', '⚡', 'বজ্র', 'Bolt'),
    Avatar('fire', '🔥', 'আগুন', 'Fire'),
    Avatar('gem', '💎', 'হীরা', 'Gem'),
    Avatar('rocket', '🚀', 'রকেট', 'Rocket'),
  ];

  static const fallback = Avatar('owl', '🦉', 'পেঁচা', 'Owl');

  static Avatar byId(String? id) => all.firstWhere(
        (a) => a.id == id,
        orElse: () => fallback,
      );
}
