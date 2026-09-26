import '../data/avatars.dart';
import '../i18n/strings.dart';

enum Gender {
  male('ছেলে', 'Male', '👦'),
  female('মেয়ে', 'Female', '👧'),
  other('অন্য', 'Other', '🧑'),
  private('বলতে চাই না', 'Prefer not to say', '🤐');

  const Gender(this.bn, this.en, this.emoji);

  final String bn;
  final String en;
  final String emoji;

  String label(bool bangla) => bangla ? bn : en;

  static Gender fromCode(String? code) => Gender.values.firstWhere(
    (g) => g.name == code,
    orElse: () => Gender.private,
  );
}

/// A signed-in learner.
///
/// No email, no phone number, no date of birth. The app asks for exactly what
/// it shows on a leaderboard, and nothing it would then have to protect.
class UserProfile {
  const UserProfile({
    required this.username,
    required this.displayName,
    required this.gender,
    required this.language,
    required this.avatarId,
    required this.createdAt,
    required this.cohort,
    this.communityId,
  });

  /// Lowercase, unique, permanent. Doubles as the account id.
  final String username;

  /// Shown on the leaderboard and feed. Changeable.
  final String displayName;

  final Gender gender;
  final AppLanguage language;
  final int avatarId;
  final DateTime createdAt;

  /// The monthly batch this learner started with.
  final String cohort;

  /// The community they are in — one at a time — or null for none.
  final String? communityId;

  UserProfile copyWith({
    String? displayName,
    Gender? gender,
    AppLanguage? language,
    int? avatarId,
  }) {
    return UserProfile(
      username: username,
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      language: language ?? this.language,
      avatarId: avatarId ?? this.avatarId,
      createdAt: createdAt,
      cohort: cohort,
      communityId: communityId,
    );
  }

  /// The same person, in community [id] — or in none.
  UserProfile inCommunity(String? id) => UserProfile(
    username: username,
    displayName: displayName,
    gender: gender,
    language: language,
    avatarId: avatarId,
    createdAt: createdAt,
    cohort: cohort,
    communityId: id == null || id.isEmpty ? null : id,
  );

  Map<String, dynamic> toJson() => {
    'username': username,
    'displayName': displayName,
    'gender': gender.name,
    'language': language.code,
    'avatarId': avatarId,
    'createdAt': createdAt.toIso8601String(),
    'cohort': cohort,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    username: json['username'] as String,
    displayName: json['displayName'] as String,
    gender: Gender.fromCode(json['gender'] as String?),
    language: AppLanguage.fromCode(json['language'] as String?),
    // Accepts the old slug form too, so accounts created before
    // avatars were numbered keep the face they picked.
    avatarId: Avatars.from(json['avatarId']).id,
    createdAt: DateTime.parse(json['createdAt'] as String),
    cohort: json['cohort'] as String? ?? '',
    communityId: switch (json['communityId']) {
      final String id when id.isNotEmpty => id,
      _ => null,
    },
  );

  /// Label for the batch someone joined in, e.g. `সেপ্টেম্বর ব্যাচ`.
  static String cohortFor(DateTime date, AppLanguage language) {
    const bnMonths = [
      'জানুয়ারি',
      'ফেব্রুয়ারি',
      'মার্চ',
      'এপ্রিল',
      'মে',
      'জুন',
      'জুলাই',
      'আগস্ট',
      'সেপ্টেম্বর',
      'অক্টোবর',
      'নভেম্বর',
      'ডিসেম্বর',
    ];
    const enMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return language == AppLanguage.bn
        ? '${bnMonths[date.month - 1]} ব্যাচ'
        : '${enMonths[date.month - 1]} batch';
  }
}
