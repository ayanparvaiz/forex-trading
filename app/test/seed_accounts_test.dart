import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/avatars.dart';
import 'package:forex_trading/data/mock_community.dart';
import 'package:forex_trading/data/seed_accounts.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/badge.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('the seed list', () {
    test('has twenty accounts, including the owner', () {
      expect(SeedAccounts.all, hasLength(20));
      expect(SeedAccounts.byUsername('ayan'), isNotNull);
      expect(SeedAccounts.byUsername('ayan')!.name, 'আয়ান পারভেজ');
    });

    test('every username is unique and passes the real validation rules', () {
      final seen = <String>{};
      for (final account in SeedAccounts.all) {
        expect(seen.add(account.username), isTrue,
            reason: '${account.username} appears twice');
        expect(
          AuthRepository.usernamePattern.hasMatch(account.username),
          isTrue,
          reason: '${account.username} is not a valid username',
        );
      }
    });

    test('avatar numbers are unique, positive and not list positions', () {
      final ids = Avatars.all.map((a) => a.id).toList();

      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate avatar id');
      expect(ids.every((id) => id > 0), isTrue);

      // Zero is never a valid id, so a missing or defaulted field cannot
      // silently resolve to a real avatar.
      expect(Avatars.byId(0).id, Avatars.fallback.id);
      expect(Avatars.byId(null).id, Avatars.fallback.id);
      expect(Avatars.byId(9999).id, Avatars.fallback.id);
    });

    test('profiles written with the old slug still resolve', () {
      // Accounts created before avatars were numbered are on real devices.
      expect(Avatars.from('tiger').id, Avatars.bySlug('tiger').id);
      expect(Avatars.from(2).slug, 'tiger');
      expect(Avatars.from('2').slug, 'tiger');
      expect(Avatars.from(null).id, Avatars.fallback.id);
    });

    test('every avatar id actually exists', () {
      for (final account in SeedAccounts.all) {
        expect(
          Avatars.all.any((a) => a.id == account.avatarId),
          isTrue,
          reason: '${account.username} points at a missing avatar',
        );
      }
    });

    test('nobody has an out-of-range discipline score or win rate', () {
      for (final account in SeedAccounts.all) {
        expect(account.disciplineScore, inInclusiveRange(0, 100));
        expect(account.winRate, inInclusiveRange(0, 1));
        expect(account.badgePoints, greaterThanOrEqualTo(0));
      }
    });

    test('the sample data makes the ranking rule argue for itself', () {
      final byBadge = [...SeedAccounts.all]
        ..sort((a, b) => b.badgePoints.compareTo(a.badgePoints));
      final byDiscipline = [...SeedAccounts.all]
        ..sort((a, b) => b.disciplineScore.compareTo(a.disciplineScore));

      // The trader with the most winning trades must not also top the
      // discipline board, or the leaderboard teaches nothing.
      expect(byBadge.first.username, isNot(byDiscipline.first.username));
      expect(byBadge.first.disciplineScore, lessThan(60));
      expect(byDiscipline.first.badgePoints, lessThan(50));

      // The sharpest version of the point: the most disciplined trader is
      // down on the year, and the least disciplined one is up.
      expect(byDiscipline.first.totalR, lessThan(0));
      expect(byBadge.first.totalR, greaterThan(0));
    });

    test('covers a spread of badge tiers rather than clustering', () {
      final tiers = SeedAccounts.all
          .map((a) => BadgeRank.of(a.badgePoints).tier)
          .toSet();

      expect(tiers.length, greaterThanOrEqualTo(4));
      expect(tiers, contains(BadgeTier.golden));
      expect(tiers, contains(BadgeTier.bronze));
    });
  });

  group('seeding', () {
    late LocalAuthRepository auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = LocalAuthRepository(prefs: await SharedPreferences.getInstance());
    });

    test('creates all twenty and signs nobody in', () async {
      final created = await SeedAccounts.ensureSeeded(auth);

      expect(created, 20);
      expect(await auth.currentUser(), isNull);
      expect(await auth.isUsernameAvailable('ayan'), isFalse);
    });

    test('is idempotent', () async {
      await SeedAccounts.ensureSeeded(auth);
      expect(await SeedAccounts.ensureSeeded(auth), 0);
    });

    test('leaves an already signed-in user alone', () async {
      await auth.signUp(
        username: 'someone',
        password: 'password1',
        displayName: 'Someone',
        gender: Gender.private,
        language: AppLanguage.en,
        avatarId: 3,
      );
      expect((await auth.currentUser())?.username, 'someone');

      await SeedAccounts.ensureSeeded(auth);

      // Adding demo accounts must never log a real person out.
      expect((await auth.currentUser())?.username, 'someone');
    });

    test('every seeded account can log in with the shared password', () async {
      await SeedAccounts.ensureSeeded(auth);

      for (final account in SeedAccounts.all) {
        final result = await auth.logIn(
          username: account.username,
          password: SeedAccounts.password,
        );
        expect(result, isA<AuthSuccess>(),
            reason: '${account.username} could not log in');
      }
    });
  });

  group('leaderboard', () {
    test('ranks on discipline, not on badge points', () {
      final ranked = MockCommunity.rank(MockCommunity.traders(AppLanguage.bn));

      for (var i = 1; i < ranked.length; i++) {
        expect(
          ranked[i - 1].disciplineScore,
          greaterThanOrEqualTo(ranked[i].disciplineScore),
        );
      }

      // The biggest badge is nowhere near the top of the list.
      final topBadgeRow =
          ranked.indexWhere((t) => t.id == 'imran');
      expect(topBadgeRow, greaterThan(ranked.length ~/ 2));
    });

    test('swaps the signed-in trader in for their seed row', () {
      final you = SeedAccounts.byUsername('ayan')!
          .toTrader(isYou: true, cohort: 'test');

      final list = MockCommunity.withYou(AppLanguage.bn, you);

      expect(list.where((t) => t.id == 'ayan'), hasLength(1));
      expect(list.firstWhere((t) => t.id == 'ayan').isYou, isTrue);
      expect(list, hasLength(SeedAccounts.all.length));
    });

    test('a trader with no seed row is appended', () {
      final stranger = SeedAccounts.all.first
          .toTrader(isYou: true, cohort: 'test');
      final list = MockCommunity.withYou(AppLanguage.bn, stranger);

      expect(list, hasLength(SeedAccounts.all.length));
    });
  });

  group('feed', () {
    test('drops anything older than seven days', () {
      final posts = MockCommunity.liveFeed(AppLanguage.bn);
      final cutoff = DateTime.now().subtract(MockCommunity.postLifetime);

      expect(posts, isNotEmpty);
      for (final post in posts) {
        expect(post.postedAt.isAfter(cutoff), isTrue);
      }
    });

    test('shows newest first', () {
      final posts = MockCommunity.liveFeed(AppLanguage.bn);

      for (var i = 1; i < posts.length; i++) {
        expect(posts[i - 1].postedAt.isBefore(posts[i].postedAt), isFalse);
      }
    });

    test('every post is written by a real account', () {
      for (final post in MockCommunity.liveFeed(AppLanguage.bn)) {
        expect(SeedAccounts.byUsername(post.author.id), isNotNull,
            reason: '${post.id} has no matching account');
      }
    });
  });
}
