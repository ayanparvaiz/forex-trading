import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/community_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/post_composer_sheet.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The composer is where everything typed in this app is typed, so what it has
/// to survive is being typed into: one character at a time, with the form
/// rebuilding around it.
void main() {
  late SharedPreferences prefs;
  late SessionController session;
  late CommunityRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    final auth = LocalAuthRepository(prefs: prefs);
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

    repository = LocalCommunityRepository(
      language: AppLanguage.en,
      prefs: prefs,
    );
  });

  /// What the composer returned, once it has closed.
  String? result;

  /// Opens the composer over a throwaway screen and returns once it is up.
  Future<void> open(
    WidgetTester tester, {
    RankShare? rank,
    String? scope,
  }) async {
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => result = await showPostComposer(
                    context,
                    repository: repository,
                    rank: rank,
                    scope: scope,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder lessonField() => find.byKey(const ValueKey('composer.lesson'));

  testWidgets('every keystroke lands, and the field keeps focus', (
    tester,
  ) async {
    // The regression this pins down: the form used to call setState on every
    // change, rebuilding the whole scrolling body — and characters went
    // missing. Typing must not depend on how the rest of the sheet rebuilds.
    await open(
      tester,
      rank: const RankShare(rank: 7, score: 84, badgeEmoji: '🥉'),
    );

    await tester.tap(lessonField());
    await tester.pump();

    const typed = 'three weeks without moving a stop';
    for (var i = 1; i <= typed.length; i++) {
      await tester.enterText(lessonField(), typed.substring(0, i));
      await tester.pump();
    }

    expect(
      tester.widget<TextField>(lessonField()).controller!.text,
      typed,
      reason: 'characters were dropped while typing',
    );

    final focus = tester.widget<TextField>(lessonField()).focusNode;
    expect(focus?.hasFocus ?? true, isTrue);
  });

  testWidgets('the form is not built lazily', (tester) async {
    // Structural, and deliberately so. A ListView disposes children once they
    // scroll out of the viewport, which for a form means the field being typed
    // into can be thrown away mid-sentence — the characters after that go
    // nowhere. Everything in a form has to be built up front, so this checks
    // the thing that guarantees it rather than a symptom of it.
    await open(
      tester,
      rank: const RankShare(rank: 7, score: 84, badgeEmoji: '🥉'),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('a rank post needs a line before it can be posted', (
    tester,
  ) async {
    await open(
      tester,
      rank: const RankShare(rank: 7, score: 84, badgeEmoji: '🥉'),
    );

    Finder postButton() => find.widgetWithText(FilledButton, 'Post');

    expect(tester.widget<FilledButton>(postButton()).onPressed, isNull);

    // Nine characters is still nothing anyone can learn from.
    await tester.enterText(lessonField(), 'held size');
    await tester.pump();
    expect(tester.widget<FilledButton>(postButton()).onPressed, isNull);

    await tester.enterText(lessonField(), 'held the size small');
    await tester.pump();
    expect(tester.widget<FilledButton>(postButton()).onPressed, isNotNull);
  });

  testWidgets('a rank post shows the rank instead of asking for a pair', (
    tester,
  ) async {
    await open(
      tester,
      rank: const RankShare(rank: 7, score: 84, badgeEmoji: '🥉'),
    );

    expect(find.text('#7'), findsOneWidget);
    // No trade behind it, so nothing to pick and nothing to ask why about.
    expect(find.text('EUR/USD'), findsNothing);
    expect(find.byKey(const ValueKey('composer.reason')), findsNothing);
  });

  testWidgets('a plain post asks for the pair and the reason', (tester) async {
    await open(tester);

    expect(find.text('EUR/USD'), findsOneWidget);
    expect(find.byKey(const ValueKey('composer.reason')), findsOneWidget);

    // Both fields are required here, so a lesson alone is not enough.
    await tester.enterText(lessonField(), 'stop was far too tight');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Post'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('says which feed it goes to, and goes there', (tester) async {
    final recording = _Recording(prefs);
    repository = recording;
    await open(
      tester,
      rank: const RankShare(rank: 7, score: 84, badgeEmoji: '🥉'),
      scope: 'global',
    );

    expect(find.text('Posting to Global'), findsOneWidget);

    await tester.enterText(lessonField(), 'held the size small');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    expect(recording.community, 'global');
    expect(result, 'global');
  });

  testWidgets('a community nobody is in is never where it goes', (
    tester,
  ) async {
    // A feed remembered from a community since left: Global instead.
    await open(
      tester,
      rank: const RankShare(rank: 7, score: 84, badgeEmoji: '🥉'),
      scope: 'bulls',
    );
    expect(find.text('Posting to Global'), findsOneWidget);
  });
}

/// Remembers which feed a rank post was written to.
class _Recording extends LocalCommunityRepository {
  _Recording(SharedPreferences prefs)
    : super(language: AppLanguage.en, prefs: prefs);

  String? community;

  @override
  Future<String?> createRankPost({
    required String uid,
    required String username,
    required int rank,
    required double score,
    required String lesson,
    String community = 'global',
  }) async {
    this.community = community;
    return 'p1';
  }
}
