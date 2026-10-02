import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/community_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/post_comment.dart';
import 'package:forex_trading/models/trader.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/community_screen.dart';
import 'package:forex_trading/screens/post_comments_sheet.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/question_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers in memory; picks remembered.
class _Answers extends LocalCommunityRepository {
  _Answers(SharedPreferences prefs)
    : super(language: AppLanguage.en, prefs: prefs);

  final picks = <String?>[];

  @override
  Stream<List<PostComment>> watchComments(String postId, {int limit = 50}) =>
      Stream.value([
        PostComment(
          id: 'c1',
          authorUid: 'u-ana',
          authorUsername: 'ana',
          authorName: 'Ana',
          authorAvatarId: 1,
          body: 'Size from the stop: pip value is about 6.7 a lot.',
          createdAt: DateTime(2026, 10, 2, 10),
        ),
      ]);

  @override
  Future<void> setBestAnswer(String postId, String? commentId) async =>
      picks.add(commentId);
}

void main() {
  late SessionController session;
  late SharedPreferences prefs;

  Future<void> pump(
    WidgetTester tester,
    Widget Function(BuildContext) body, {
    AppLanguage language = AppLanguage.en,
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final auth = LocalAuthRepository(prefs: prefs);
    await auth.signUp(
      username: 'tester',
      password: 'secret123',
      displayName: 'Tester',
      gender: Gender.male,
      language: language,
      avatarId: 1,
    );
    session = SessionController(auth);
    await session.restore();
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

  FeedPost question({String? answerId, String author = 'tester'}) =>
      FeedPost.question(
        id: 'q1',
        author: Trader(
          id: author,
          name: 'Tester',
          avatarId: 1,
          disciplineScore: 90,
          badgePoints: 0,
          totalR: 0,
          tradeCount: 0,
          winRate: 0,
          journalStreak: 0,
          cohort: '',
        ),
        postedAt: DateTime(2026, 10, 2, 9),
        lesson: 'How do you size a trade on USD/JPY?',
        claps: 0,
        commentCount: 1,
        answerId: answerId,
      );

  testWidgets('the question sheet wants ten letters at least', (tester) async {
    final asked = <String?>[];
    await pump(
      tester,
      (c) => TextButton(
        onPressed: () async => asked.add(await showQuestionSheet(c)),
        child: const Text('ask'),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    FilledButton ask() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    await tester.enterText(find.byType(TextField), 'Why?');
    await tester.pump();
    expect(ask().onPressed, isNull);
    await tester.enterText(
      find.byType(TextField),
      '  How do you trail a stop?  ',
    );
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(asked, ['How do you trail a stop?']);
  });

  testWidgets('a question on the feed: open, then answered', (tester) async {
    await pump(
      tester,
      (_) => SingleChildScrollView(
        child: FeedCard(
          post: question(),
          s: const Strings(AppLanguage.en),
          repository: _Answers(prefs),
        ),
      ),
    );
    expect(find.text('QUESTION'), findsOneWidget);
    expect(find.text('How do you size a trade on USD/JPY?'), findsOneWidget);
    expect(find.text('Open question'), findsOneWidget);
    expect(find.text('Why I took it'), findsNothing);
  });

  testWidgets('who asked picks the best answer, and can take it back', (
    tester,
  ) async {
    late _Answers repo;
    await pump(tester, (c) {
      repo = _Answers(prefs);
      return TextButton(
        onPressed: () =>
            showPostComments(c, postId: 'q1', repository: repo, pickBest: true),
        child: const Text('open'),
      );
    });
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as best answer'));
    await tester.pumpAndSettle();
    expect(repo.picks, ['c1']);
    expect(find.text('Best answer'), findsOneWidget);
    await tester.tap(find.text('Remove best answer'));
    await tester.pumpAndSettle();
    expect(repo.picks, ['c1', null]);
    expect(find.text('Best answer'), findsNothing);
  });

  testWidgets("anyone else sees the pick, and can't change it", (tester) async {
    await pump(tester, (c) {
      final repo = _Answers(prefs);
      return TextButton(
        onPressed: () =>
            showPostComments(c, postId: 'q1', repository: repo, answerId: 'c1'),
        child: const Text('open'),
      );
    });
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Best answer'), findsOneWidget);
    expect(find.text('Mark as best answer'), findsNothing);
    expect(find.text('Remove best answer'), findsNothing);
  });
}
