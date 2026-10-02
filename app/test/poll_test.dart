import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/chat.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/poll_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a poll goes to the store and comes back the same', () {
    const poll = Poll(question: 'Which pair?', options: ['EURUSD', 'GBPUSD']);
    expect(poll.toJson(), {
      'type': 'poll',
      'question': 'Which pair?',
      'options': ['EURUSD', 'GBPUSD'],
    });
    final back = MessageAttachment.fromJson(poll.toJson())! as Poll;
    expect(back.question, 'Which pair?');
    expect(back.options, ['EURUSD', 'GBPUSD']);
  });

  test('votes are counted per answer; a vote moves, or goes', () {
    final m = ChatMessage(
      id: 'p1',
      senderUid: 'ana',
      text: '',
      sentAt: DateTime(2026, 10, 2),
      unsent: false,
      pending: false,
      attachment: const Poll(question: '?', options: ['a', 'b', 'c']),
      // One out of range, as no app of ours would write: not counted.
      votes: const {'ana': 0, 'bo': 2, 'cy': 2, 'di': 7},
    );
    expect(m.voteCounts(3), [1, 0, 2]);
    expect(m.withVote('bo', 1).voteCounts(3), [1, 1, 1]);
    expect(m.withVote('bo', null).voteCounts(3), [1, 0, 1]);
    expect(m.withVote('me', 0).votes['me'], 0);
  });

  test('a preview says it is a poll', () {
    expect(
      const Strings(AppLanguage.en).messagePreview('', 'poll'),
      '🗳️ Poll',
    );
  });

  Future<List<Poll?>> openSheet(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    )..setLanguage(AppLanguage.en);
    final asked = <Poll?>[];
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => asked.add(await showPollSheet(context)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return asked;
  }

  FilledButton ask(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Ask'));

  testWidgets('asking needs a question and two answers; blanks are left out', (
    tester,
  ) async {
    final asked = await openSheet(tester);
    expect(ask(tester).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Question'),
      ' Which session? ',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Answer 1'), 'Asia');
    await tester.pump();
    expect(ask(tester).onPressed, isNull, reason: 'one answer is no choice');

    // Up to four, then no more to add.
    await tester.tap(find.text('Add an answer'));
    await tester.pump();
    await tester.tap(find.text('Add an answer'));
    await tester.pump();
    expect(find.text('Answer 4'), findsOneWidget);
    expect(find.text('Add an answer'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Answer 3'),
      'London',
    );
    await tester.pump();
    expect(ask(tester).onPressed, isNotNull);

    // The fourth, left blank, is taken out; the third can go too.
    await tester.tap(find.byTooltip('Remove this answer').last);
    await tester.pump();
    expect(find.text('Answer 4'), findsNothing);

    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    expect(asked, hasLength(1));
    expect(asked.single!.question, 'Which session?');
    expect(asked.single!.options, ['Asia', 'London']);
  });

  testWidgets('fits a small phone with the keyboard up', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 520);
    addTearDown(tester.view.reset);
    await openSheet(tester);
    for (var i = 0; i < 2; i++) {
      // Below the keyboard: scrolled to, as a thumb would.
      await tester.ensureVisible(find.text('Add an answer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add an answer'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Answer 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Ask'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
