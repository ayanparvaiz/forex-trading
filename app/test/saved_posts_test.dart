import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/community_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/screens/saved_posts_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saving and forgetting a post', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalCommunityRepository(
      language: AppLanguage.en,
      prefs: await SharedPreferences.getInstance(),
    );
    final first = (await repo.feed()).items.first;
    expect(await repo.isSaved(first.id, 'u1'), isFalse);
    await repo.setSaved(first.id, 'u1', saved: true);
    expect(await repo.isSaved(first.id, 'u1'), isTrue);
    expect([for (final p in await repo.savedPosts('u1')) p.id], [first.id]);
    await repo.setSaved(first.id, 'u1', saved: false);
    expect(await repo.savedPosts('u1'), isEmpty);
  });

  testWidgets('nothing saved says how to save', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    )..setLanguage(AppLanguage.en);
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const SavedPostsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);
  });
}
