import '../i18n/strings.dart';
import '../models/trader.dart';
import '../models/user_profile.dart';
import 'auth_repository.dart';
import 'avatars.dart';

/// One of the twenty accounts the app ships with.
///
/// These are real, loggable accounts rather than decorative rows: the
/// leaderboard, the feed and the profile screens all read from this list, so
/// what you see as a visitor is what you get when you sign in as them.
class SeedAccount {
  const SeedAccount({
    required this.username,
    required this.name,
    required this.avatarId,
    required this.gender,
    required this.language,
    required this.badgePoints,
    required this.totalR,
    required this.disciplineScore,
    required this.tradeCount,
    required this.winRate,
    required this.journalStreak,
  });

  final String username;
  final String name;
  final int avatarId;
  final Gender gender;
  final AppLanguage language;

  /// Net winning trades, which sets the badge tier.
  final int badgePoints;

  /// Cumulative R. Set per account rather than derived, because the story the
  /// leaderboard has to tell — the most disciplined trader being down, the
  /// most reckless one being up — is not something a win-rate formula will
  /// produce on its own.
  final double totalR;

  /// 0–100, from rule-following alone.
  final double disciplineScore;

  final int tradeCount;
  final double winRate;
  final int journalStreak;

  Trader toTrader({bool isYou = false, required String cohort}) => Trader(
    id: username,
    name: name,
    avatarEmoji: Avatars.byId(avatarId).emoji,
    disciplineScore: disciplineScore,
    badgePoints: badgePoints,
    totalR: totalR,
    tradeCount: tradeCount,
    winRate: winRate,
    journalStreak: journalStreak,
    cohort: cohort,
    isYou: isYou,
  );
}

/// The twenty accounts that populate a fresh install.
class SeedAccounts {
  const SeedAccounts._();

  /// Shared password for every seeded account, so any of them can be signed
  /// into while the app is being built.
  ///
  /// This is demo scaffolding and it has to go before real people are on here —
  /// twenty accounts with a published password is not a thing to ship.
  static const password = 'demo1234';

  /// The account the app belongs to.
  static const owner = 'ayan';

  /// Deliberately arranged so the leaderboard argues with itself.
  ///
  /// `imran` has the most winning trades and the worst discipline; `rifat` has
  /// the best discipline and a losing record. Put those two next to each other
  /// and the ranking rule explains itself without a paragraph of copy.
  static const all = <SeedAccount>[
    SeedAccount(
      username: owner,
      name: 'আয়ান পারভেজ',
      avatarId: 2,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 64,
      totalR: 18.4,
      disciplineScore: 86,
      tradeCount: 48,
      winRate: 0.52,
      journalStreak: 12,
    ),
    SeedAccount(
      username: 'rifat',
      name: 'রিফাত হাসান',
      avatarId: 1,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 9,
      totalR: -4.2,
      disciplineScore: 96,
      tradeCount: 41,
      winRate: 0.41,
      journalStreak: 38,
    ),
    SeedAccount(
      username: 'nusrat',
      name: 'নুসরাত জাহান',
      avatarId: 16,
      gender: Gender.female,
      language: AppLanguage.bn,
      badgePoints: 128,
      totalR: 41.6,
      disciplineScore: 93,
      tradeCount: 96,
      winRate: 0.5,
      journalStreak: 31,
    ),
    SeedAccount(
      username: 'tanvir',
      name: 'তানভীর আহমেদ',
      avatarId: 4,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 62,
      totalR: 12.8,
      disciplineScore: 88,
      tradeCount: 52,
      winRate: 0.44,
      journalStreak: 19,
    ),
    SeedAccount(
      username: 'sadia',
      name: 'সাদিয়া ইসলাম',
      avatarId: 11,
      gender: Gender.female,
      language: AppLanguage.bn,
      badgePoints: 31,
      totalR: 9.1,
      disciplineScore: 71,
      tradeCount: 28,
      winRate: 0.57,
      journalStreak: 6,
    ),
    SeedAccount(
      username: 'imran',
      name: 'ইমরান খান',
      avatarId: 5,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 214,
      totalR: 33.7,
      disciplineScore: 54,
      tradeCount: 196,
      winRate: 0.49,
      journalStreak: 0,
    ),
    SeedAccount(
      username: 'mehedi',
      name: 'মেহেদী হাসান',
      avatarId: 3,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 0,
      totalR: -28.4,
      disciplineScore: 31,
      tradeCount: 134,
      winRate: 0.38,
      journalStreak: 0,
    ),
    SeedAccount(
      username: 'tasnim',
      name: 'তাসনিম আক্তার',
      avatarId: 14,
      gender: Gender.female,
      language: AppLanguage.bn,
      badgePoints: 44,
      totalR: 15.2,
      disciplineScore: 82,
      tradeCount: 36,
      winRate: 0.56,
      journalStreak: 14,
    ),
    SeedAccount(
      username: 'shakib',
      name: 'সাকিব রহমান',
      avatarId: 9,
      gender: Gender.male,
      language: AppLanguage.en,
      badgePoints: 97,
      totalR: 22.9,
      disciplineScore: 68,
      tradeCount: 88,
      winRate: 0.53,
      journalStreak: 3,
    ),
    SeedAccount(
      username: 'farhana',
      name: 'ফারহানা ইয়াসমিন',
      avatarId: 6,
      gender: Gender.female,
      language: AppLanguage.bn,
      badgePoints: 26,
      totalR: 11.3,
      disciplineScore: 90,
      tradeCount: 22,
      winRate: 0.59,
      journalStreak: 21,
    ),
    SeedAccount(
      username: 'arif',
      name: 'আরিফুল ইসলাম',
      avatarId: 8,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 71,
      totalR: 16.8,
      disciplineScore: 77,
      tradeCount: 61,
      winRate: 0.55,
      journalStreak: 9,
    ),
    SeedAccount(
      username: 'jarin',
      name: 'জারিন তাসনিয়া',
      avatarId: 19,
      gender: Gender.female,
      language: AppLanguage.bn,
      badgePoints: 132,
      totalR: 38.4,
      disciplineScore: 84,
      tradeCount: 104,
      winRate: 0.56,
      journalStreak: 27,
    ),
    SeedAccount(
      username: 'sabbir',
      name: 'সাব্বির আহমেদ',
      avatarId: 10,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 18,
      totalR: -3.6,
      disciplineScore: 62,
      tradeCount: 44,
      winRate: 0.45,
      journalStreak: 2,
    ),
    SeedAccount(
      username: 'mim',
      name: 'মাইশা মিম',
      avatarId: 7,
      gender: Gender.female,
      language: AppLanguage.bn,
      badgePoints: 5,
      totalR: 2.7,
      disciplineScore: 79,
      tradeCount: 13,
      winRate: 0.54,
      journalStreak: 11,
    ),
    SeedAccount(
      username: 'raihan',
      name: 'রায়হান কবির',
      avatarId: 17,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 203,
      totalR: 47.2,
      disciplineScore: 74,
      tradeCount: 168,
      winRate: 0.51,
      journalStreak: 16,
    ),
    SeedAccount(
      username: 'anika',
      name: 'আনিকা তাবাসসুম',
      avatarId: 15,
      gender: Gender.female,
      language: AppLanguage.en,
      badgePoints: 38,
      totalR: 13.9,
      disciplineScore: 91,
      tradeCount: 33,
      winRate: 0.58,
      journalStreak: 24,
    ),
    SeedAccount(
      username: 'niloy',
      name: 'নিলয় দাস',
      avatarId: 12,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 12,
      totalR: -11.5,
      disciplineScore: 47,
      tradeCount: 76,
      winRate: 0.42,
      journalStreak: 0,
    ),
    SeedAccount(
      username: 'proma',
      name: 'প্রমা চৌধুরী',
      avatarId: 18,
      gender: Gender.female,
      language: AppLanguage.bn,
      badgePoints: 88,
      totalR: 24.6,
      disciplineScore: 80,
      tradeCount: 72,
      winRate: 0.54,
      journalStreak: 18,
    ),
    SeedAccount(
      username: 'sohan',
      name: 'সোহান মাহমুদ',
      avatarId: 13,
      gender: Gender.male,
      language: AppLanguage.bn,
      badgePoints: 2,
      totalR: -19.8,
      disciplineScore: 39,
      tradeCount: 58,
      winRate: 0.4,
      journalStreak: 0,
    ),
    SeedAccount(
      username: 'ishrat',
      name: 'ইশরাত জাহান',
      avatarId: 20,
      gender: Gender.female,
      language: AppLanguage.bn,
      badgePoints: 156,
      totalR: 44.1,
      disciplineScore: 87,
      tradeCount: 118,
      winRate: 0.55,
      journalStreak: 29,
    ),
  ];

  static SeedAccount? byUsername(String username) {
    for (final account in all) {
      if (account.username == username) return account;
    }
    return null;
  }

  /// Creates whichever seed accounts do not exist yet.
  ///
  /// Idempotent: safe to call on every launch, and it never touches an account
  /// that is already there, so a seeded user who changed their avatar keeps it.
  static Future<int> ensureSeeded(AuthRepository auth) async {
    var created = 0;
    for (final account in all) {
      if (!await auth.isUsernameAvailable(account.username)) continue;

      final result = await auth.signUp(
        username: account.username,
        password: password,
        displayName: account.name,
        gender: account.gender,
        language: account.language,
        avatarId: account.avatarId,
        // Never touch the session. If this list grows in a later release,
        // seeding must not sign an existing user out of their own account.
        startSession: false,
      );
      if (result is AuthSuccess) created++;
    }
    return created;
  }
}
