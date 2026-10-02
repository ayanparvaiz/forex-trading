import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/account_scope.dart';
import 'package:forex_trading/data/account_store.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/community_repository.dart';
import 'package:forex_trading/data/lesson_progress.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/lesson.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/community_screen.dart';
import 'package:forex_trading/screens/journal_screen.dart';
import 'package:forex_trading/screens/learn_screen.dart';
import 'package:forex_trading/screens/monthly_report_screen.dart';
import 'package:forex_trading/screens/onboarding_screen.dart';
import 'package:forex_trading/screens/portfolio_screen.dart';
import 'package:forex_trading/screens/profile_screen.dart';
import 'package:forex_trading/screens/risk_calculator_screen.dart';
import 'package:forex_trading/screens/saved_posts_screen.dart';
import 'package:forex_trading/screens/settings_screen.dart';
import 'package:forex_trading/screens/trade_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every screen that runs without a server, on the smallest phone the app
/// supports (iPhone SE, 320 × 568), in both languages — Bangla words run
/// longer. Nothing may overflow: an overflow is a striped bar on a real
/// phone, and a failed test here.
void main() {
  final screens = <String, Widget Function(CommunityRepository repo)>{
    'portfolio': (_) => const PortfolioScreen(),
    'trade': (_) => const TradeScreen(),
    'journal': (_) => const JournalScreen(),
    'community': (_) => const CommunityScreen(),
    'settings': (_) => const SettingsScreen(),
    'risk calculator': (_) => const RiskCalculatorScreen(balance: 10000),
    'monthly report': (_) => const MonthlyReportScreen(),
    'saved posts': (_) => const SavedPostsScreen(),
    'learn': (_) => LearnScreen(progress: MemoryLessonProgress()),
    'a lesson': (_) => LessonScreen(lesson: Lesson.all.first),
    'tour': (_) => const OnboardingScreen(),
    'a profile': (repo) => ProfileScreen(username: 'rifat', repository: repo),
  };

  for (final language in AppLanguage.values) {
    for (final MapEntry(key: name, value: build) in screens.entries) {
      testWidgets('$name fits a small phone, in ${language.name}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(640, 1136);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final auth = LocalAuthRepository(prefs: prefs);
        await auth.signUp(
          username: 'tester',
          password: 'secret123',
          displayName: 'Tahmid Hasan Chowdhury',
          gender: Gender.male,
          language: language,
          avatarId: 1,
        );
        final session = SessionController(auth);
        await session.restore();
        final store = AccountStore();
        final repo = LocalCommunityRepository(language: language, prefs: prefs);

        await tester.pumpWidget(
          SessionScope(
            controller: session,
            child: AccountScope(
              store: store,
              child: MaterialApp(theme: buildAppTheme(), home: build(repo)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        final error = tester.takeException();
        // The market ticks every second; stop it before the test ends.
        await tester.pumpWidget(const SizedBox());
        store.dispose();
        expect(error, isNull);
      });
    }
  }
}
