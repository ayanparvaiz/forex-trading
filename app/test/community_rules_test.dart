import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/community.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/community_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Community community({List<String> rules = const []}) => Community(
    id: 'bulls1',
    name: 'Dhaka Bulls',
    description: '',
    createdBy: 'u-admin',
    memberCount: 4,
    createdAt: DateTime(2026, 9, 1),
    rules: rules,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget Function(BuildContext) body, {
    AppLanguage language = AppLanguage.en,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    )..setLanguage(language);
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: Builder(builder: body)),
        ),
      ),
    );
  }

  testWidgets('joining asks to agree to the rules; none, nothing to ask', (
    tester,
  ) async {
    final answers = <bool>[];
    late BuildContext ctx;
    await pump(tester, (c) {
      ctx = c;
      return const SizedBox();
    });
    answers.add(await agreeToRules(ctx, community()));
    expect(answers, [true]);

    final asking = agreeToRules(
      ctx,
      community(rules: ['Respect everyone', 'No signals for sale']),
    );
    await tester.pumpAndSettle();
    expect(find.text('The rules of Dhaka Bulls'), findsOneWidget);
    expect(find.text('No signals for sale'), findsOneWidget);
    await tester.tap(find.text('Agree and join'));
    await tester.pumpAndSettle();
    expect(await asking, isTrue);

    final declining = agreeToRules(ctx, community(rules: ['Respect everyone']));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await declining, isFalse);
  });

  testWidgets('the card: numbered for everyone, nothing when none', (
    tester,
  ) async {
    await pump(
      tester,
      (_) => CommunityRulesCard(
        community: community(rules: ['Respect everyone', 'Plan first']),
        isAdmin: false,
      ),
    );
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('Plan first'), findsOneWidget);
    expect(find.text('Edit rules'), findsNothing);

    await pump(
      tester,
      (_) => CommunityRulesCard(community: community(), isAdmin: false),
    );
    expect(find.text('Community rules'), findsNothing);
  });

  testWidgets('the admin writes them: up to five, blanks left out', (
    tester,
  ) async {
    final saved = <List<String>?>[];
    await pump(
      tester,
      (c) => TextButton(
        onPressed: () async => saved.add(await showRulesEditor(c, const [])),
        child: const Text('edit'),
      ),
    );
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '  Respect everyone ');
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Add a rule'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Add a rule'), findsNothing, reason: 'five at most');
    await tester.enterText(find.byType(TextField).at(2), 'Plan first');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved.single, ['Respect everyone', 'Plan first']);
  });

  testWidgets('fits a small phone, in Bangla', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      (_) => SingleChildScrollView(
        child: CommunityRulesCard(
          community: community(rules: ['x' * 120, 'সবাইকে সম্মান করুন']),
          isAdmin: true,
        ),
      ),
      language: AppLanguage.bn,
    );
    expect(tester.takeException(), isNull);
  });
}
