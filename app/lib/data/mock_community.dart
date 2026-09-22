import '../models/trader.dart';

/// Seed community data for the prototype.
///
/// Read the leaderboard order carefully: Rifat sits top with **negative** total
/// R, and the trader with the biggest profit is fourth. That is not an accident
/// in the sample data — it is the product decision, made visible.
class MockCommunity {
  const MockCommunity._();

  static const you = Trader(
    id: 'you',
    name: 'আপনি',
    avatarEmoji: '🫵',
    disciplineScore: 78,
    totalR: 1.9,
    tradeCount: 6,
    winRate: 0.67,
    journalStreak: 4,
    cohort: 'সেপ্টেম্বর ব্যাচ',
    isYou: true,
  );

  static const traders = <Trader>[
    Trader(
      id: 't1',
      name: 'রিফাত হাসান',
      avatarEmoji: '🦉',
      disciplineScore: 96,
      totalR: -0.4,
      tradeCount: 41,
      winRate: 0.41,
      journalStreak: 38,
      cohort: 'সেপ্টেম্বর ব্যাচ',
    ),
    Trader(
      id: 't2',
      name: 'নুসরাত জাহান',
      avatarEmoji: '🌙',
      disciplineScore: 93,
      totalR: 8.2,
      tradeCount: 36,
      winRate: 0.5,
      journalStreak: 31,
      cohort: 'সেপ্টেম্বর ব্যাচ',
    ),
    Trader(
      id: 't3',
      name: 'তানভীর আহমেদ',
      avatarEmoji: '🐅',
      disciplineScore: 88,
      totalR: 3.1,
      tradeCount: 52,
      winRate: 0.44,
      journalStreak: 19,
      cohort: 'আগস্ট ব্যাচ',
    ),
    you,
    Trader(
      id: 't4',
      name: 'সাদিয়া ইসলাম',
      avatarEmoji: '🐿️',
      disciplineScore: 71,
      totalR: 12.6,
      tradeCount: 28,
      winRate: 0.57,
      journalStreak: 6,
      cohort: 'সেপ্টেম্বর ব্যাচ',
    ),
    Trader(
      id: 't5',
      name: 'ইমরান খান',
      avatarEmoji: '🐘',
      disciplineScore: 54,
      totalR: 21.4,
      tradeCount: 96,
      winRate: 0.49,
      journalStreak: 0,
      cohort: 'আগস্ট ব্যাচ',
    ),
    Trader(
      id: 't6',
      name: 'মেহেদী হাসান',
      avatarEmoji: '🦊',
      disciplineScore: 31,
      totalR: -18.7,
      tradeCount: 134,
      winRate: 0.38,
      journalStreak: 0,
      cohort: 'সেপ্টেম্বর ব্যাচ',
    ),
  ];

  /// Leaderboard order: discipline first, trade count as the tiebreak.
  static List<Trader> get leaderboard {
    final sorted = [...traders]..sort((a, b) {
        final byScore = b.disciplineScore.compareTo(a.disciplineScore);
        return byScore != 0 ? byScore : b.tradeCount.compareTo(a.tradeCount);
      });
    return sorted;
  }

  static Trader _byId(String id) => traders.firstWhere((t) => t.id == id);

  static List<FeedPost> get feed {
    final now = DateTime.now();
    return [
      FeedPost(
        id: 'p1',
        author: _byId('t1'),
        symbol: 'EUR/USD',
        rMultiple: -1.0,
        postedAt: now.subtract(const Duration(hours: 2)),
        reason: 'H4 ডিমান্ড জোনে বুলিশ পিন বার, লন্ডন ওপেনের আগে এন্ট্রি।',
        lesson:
            'স্টপ লেগেছে। কিন্তু সেটআপ, সাইজ, স্টপ — সব প্ল্যান মতো ছিল। '
            'এরকম ১০টা ট্রেডের ৪টা হারলেও সমস্যা নেই। আজ কিছু বদলাব না।',
        followedRules: true,
        claps: 47,
        commentCount: 12,
      ),
      FeedPost(
        id: 'p2',
        author: _byId('t5'),
        symbol: 'GBP/USD',
        rMultiple: 4.8,
        postedAt: now.subtract(const Duration(hours: 6)),
        reason: 'নিউজের আগে ঢুকেছিলাম, বড় মুভ ধরব ভেবে।',
        lesson:
            '৪.৮R পেয়েছি, কিন্তু রিস্ক ছিল ৭%। উল্টো দিকে গেলে অ্যাকাউন্টের '
            'এক-তৃতীয়াংশ চলে যেত। এটা ভালো ট্রেড ছিল না, ভাগ্য ভালো ছিল।',
        followedRules: false,
        claps: 9,
        commentCount: 31,
      ),
      FeedPost(
        id: 'p3',
        author: _byId('t2'),
        symbol: 'USD/JPY',
        rMultiple: 2.1,
        postedAt: now.subtract(const Duration(hours: 11)),
        reason: 'ডেইলি ব্রেকআউটের রিটেস্ট, ১৫মি তে কনফার্মেশন।',
        lesson:
            'ব্রেকআউটে সাথে সাথে ঢুকিনি — রিটেস্টের জন্য ৪০ মিনিট অপেক্ষা '
            'করেছি। ওই অপেক্ষাটাই স্টপ ২৫ পিপ থেকে ১২ পিপে নামিয়ে দিয়েছে।',
        followedRules: true,
        claps: 63,
        commentCount: 8,
      ),
      FeedPost(
        id: 'p4',
        author: _byId('t3'),
        symbol: 'EUR/USD',
        rMultiple: -1.0,
        postedAt: now.subtract(const Duration(days: 1)),
        reason: 'সাপোর্ট ব্রেক করে আবার উপরে উঠে এসেছিল — ফলস ব্রেকডাউন ধরেছি।',
        lesson:
            'হেরেছি, তবু জার্নাল লিখছি কারণ ভুলটা এন্ট্রিতে না — সাইজিংয়ে। '
            'স্টপ ৩৫ পিপ দূরে ছিল, তাই লট আরও ছোট হওয়া উচিত ছিল।',
        followedRules: true,
        claps: 38,
        commentCount: 5,
      ),
    ];
  }
}
