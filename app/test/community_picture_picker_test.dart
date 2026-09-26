import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/community_badge.dart';
import 'package:forex_trading/widgets/community_picture_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SessionController session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthRepository(
      prefs: await SharedPreferences.getInstance(),
    );
    await auth.signUp(
      username: 'rifat',
      password: 'secret123',
      displayName: 'Rifat Hasan',
      gender: Gender.male,
      language: AppLanguage.en,
      avatarId: 1,
    );
    session = SessionController(auth);
    await session.restore();
  });

  Widget app(Widget home) => SessionScope(
    controller: session,
    child: MaterialApp(theme: buildAppTheme(), home: home),
  );

  testWidgets('every shelf is there, and a tap is the picture chosen', (
    tester,
  ) async {
    int? picked = -1;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async =>
                    picked = await pickCommunityPicture(context, current: 3),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a picture'), findsOneWidget);
    // The sheet's own scroll view — the shelves inside it do not scroll.
    final sheet = find.byType(Scrollable).first;
    for (final shelf in ['The market', 'Discipline', 'Nature', 'Emblems']) {
      await tester.scrollUntilVisible(find.text(shelf), 100, scrollable: sheet);
      expect(find.text(shelf), findsOneWidget);
    }

    await tester.scrollUntilVisible(
      find.text('Water lily'),
      -100,
      scrollable: sheet,
    );
    await tester.tap(find.text('Water lily'));
    await tester.pumpAndSettle();
    expect(picked, 21);
  });

  testWidgets('a badge shows its picture, or its initial without one', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: Column(
            children: [
              CommunityBadge(id: 'abc123', name: 'dhaka bulls', avatarId: 1),
              CommunityBadge(id: 'def456', name: 'sylhet bears'),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
  });
}
