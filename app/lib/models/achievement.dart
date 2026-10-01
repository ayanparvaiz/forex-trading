/// A milestone a trader keeps once reached, earned from their own closed
/// trades. The worker decides who has earned what (worker/src/achievements.js)
/// and stores the ids on the profile; this is how each one looks.
class Achievement {
  const Achievement(
    this.id,
    this.emoji,
    this.bn,
    this.en,
    this.howBn,
    this.howEn,
  );

  /// Stored on profiles, and the worker's name for it. Never renamed.
  final String id;
  final String emoji;
  final String bn;
  final String en;

  /// What it takes, in a line.
  final String howBn;
  final String howEn;

  String title(bool bangla) => bangla ? bn : en;
  String how(bool bangla) => bangla ? howBn : howEn;

  /// Every one there is, in the worker's order.
  static const all = <Achievement>[
    Achievement(
      'first_trade',
      '🌱',
      'প্রথম ট্রেড',
      'First trade',
      'প্রথম ট্রেড ক্লোজ করুন',
      'Close your first trade',
    ),
    Achievement(
      'ranked',
      '🏁',
      'লিডারবোর্ডে',
      'On the board',
      '৫টা ট্রেড ক্লোজ করে লিডারবোর্ডে উঠুন',
      'Close five trades and join the leaderboard',
    ),
    Achievement(
      'fifty_trades',
      '📈',
      '৫০ ট্রেড',
      '50 trades',
      '৫০টা ট্রেড ক্লোজ করুন',
      'Close fifty trades',
    ),
    Achievement(
      'hundred_trades',
      '💯',
      '১০০ ট্রেড',
      '100 trades',
      '১০০টা ট্রেড ক্লোজ করুন',
      'Close a hundred trades',
    ),
    Achievement(
      'clean_ten',
      '🧘',
      'টানা ১০ ক্লিন',
      '10 clean in a row',
      'কোনো নিয়ম না ভেঙে টানা ১০টা ট্রেড',
      'Ten trades in a row without breaking a rule',
    ),
    Achievement(
      'big_winner',
      '🎯',
      '৩R জয়',
      'A 3R winner',
      'একটা ট্রেডে ৩R বা তার বেশি',
      'Win 3R or more on a single trade',
    ),
    Achievement(
      'streak_7',
      '🔥',
      '৭ দিনের স্ট্রিক',
      '7-day streak',
      'টানা ৭ দিন জার্নাল লিখুন',
      'Journal seven days in a row',
    ),
    Achievement(
      'streak_30',
      '🏆',
      '৩০ দিনের স্ট্রিক',
      '30-day streak',
      'টানা ৩০ দিন জার্নাল লিখুন',
      'Journal thirty days in a row',
    ),
    Achievement(
      'iron_discipline',
      '🛡️',
      'লৌহ ডিসিপ্লিন',
      'Iron discipline',
      '২০টা ট্রেডের পরও ডিসিপ্লিন ৯০+',
      'A discipline score of 90+ across twenty trades',
    ),
  ];

  /// The ones in [ids] this version knows, in order. An id from a newer
  /// worker is left out rather than drawn as something it is not.
  static List<Achievement> of(Iterable<String> ids) {
    final have = ids.toSet();
    return [
      for (final a in all)
        if (have.contains(a.id)) a,
    ];
  }
}
