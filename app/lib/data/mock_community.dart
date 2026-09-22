import '../i18n/strings.dart';
import '../models/trader.dart';
import '../models/user_profile.dart';
import 'seed_accounts.dart';

/// Builds the leaderboard and feed out of the seeded accounts.
///
/// Read the leaderboard order carefully. Rifat sits near the top on a losing
/// record, and Imran — who has won more trades than anyone — sits well below
/// him. That is not an accident in the sample data; it is the product decision,
/// made visible the moment anyone opens the tab.
class MockCommunity {
  const MockCommunity._();

  /// Alternating batches, so the cohort filter has something to filter.
  static String _cohortFor(int index, AppLanguage language) {
    final month = index.isEven ? DateTime(2026, 9) : DateTime(2026, 8);
    return UserProfile.cohortFor(month, language);
  }

  static List<Trader> traders(AppLanguage language) {
    final list = <Trader>[];
    for (var i = 0; i < SeedAccounts.all.length; i++) {
      list.add(
        SeedAccounts.all[i].toTrader(cohort: _cohortFor(i, language)),
      );
    }
    return list;
  }

  /// The seeded list with [you] swapped in for the matching username.
  ///
  /// A signed-in trader has to see their own live numbers, not the frozen seed
  /// row — otherwise the leaderboard quietly lies about the one entry they can
  /// actually check.
  static List<Trader> withYou(AppLanguage language, Trader? you) {
    final list = traders(language);
    if (you == null) return list;

    final index = list.indexWhere((t) => t.id == you.id);
    if (index >= 0) {
      list[index] = you;
    } else {
      list.add(you);
    }
    return list;
  }

  /// Ranked by discipline, with trade count as the tiebreak.
  static List<Trader> rank(List<Trader> traders) {
    final sorted = [...traders]..sort((a, b) {
        final byScore = b.disciplineScore.compareTo(a.disciplineScore);
        return byScore != 0 ? byScore : b.tradeCount.compareTo(a.tradeCount);
      });
    return sorted;
  }

  static Trader _author(String username, AppLanguage language) {
    final all = traders(language);
    return all.firstWhere((t) => t.id == username, orElse: () => all.first);
  }

  /// Shared journal entries.
  ///
  /// Posts expire after seven days, so the feed is always what people are doing
  /// now rather than an archive nobody scrolls.
  static List<FeedPost> feed(AppLanguage language) {
    final now = DateTime.now();
    return [
      FeedPost(
        id: 'p1',
        author: _author('rifat', language),
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
        author: _author('imran', language),
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
        author: _author('nusrat', language),
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
        author: _author('jarin', language),
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
      FeedPost(
        id: 'p5',
        author: _author('raihan', language),
        symbol: 'GBP/USD',
        rMultiple: 1.8,
        postedAt: now.subtract(const Duration(days: 2)),
        reason: 'এশিয়ান রেঞ্জ ব্রেক, লন্ডন ওপেনে কনফার্মেশন।',
        lesson:
            'টার্গেটের ৮০% এ বেরিয়ে এসেছি কারণ ভয় পেয়েছিলাম। পুরো টার্গেট '
            'হিট করেছিল। ভয় আমার ০.৪R খেয়েছে।',
        followedRules: true,
        claps: 52,
        commentCount: 17,
      ),
      FeedPost(
        id: 'p6',
        author: _author('mehedi', language),
        symbol: 'USD/JPY',
        rMultiple: -3.2,
        postedAt: now.subtract(const Duration(days: 4)),
        reason: 'নিচে যাচ্ছিল, ভাবলাম ফিরবে। স্টপ সরিয়ে দিয়েছিলাম।',
        lesson:
            'স্টপ সরানোটাই ভুল। −১R হতো, হয়েছে −৩.২R। একটা সিদ্ধান্ত '
            'একটা লসকে তিন গুণ করে দিয়েছে।',
        followedRules: false,
        claps: 91,
        commentCount: 44,
      ),
    ];
  }

  /// How long a post stays in the feed before it disappears.
  static const postLifetime = Duration(days: 7);

  /// Posts that have not expired yet.
  static List<FeedPost> liveFeed(AppLanguage language) {
    final cutoff = DateTime.now().subtract(postLifetime);
    return feed(language)
        .where((p) => p.postedAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }
}
