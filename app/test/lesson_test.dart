import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/lesson.dart';
import 'package:forex_trading/screens/learn_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the lessons the worker and the rules know, and no others', () {
    final ids = [for (final l in Lesson.all) l.id];
    final worker = File('../worker/src/achievements.js').readAsStringSync();
    final lessons = RegExp(r"LESSONS = \[(.*?)\]").firstMatch(worker)![1]!;
    expect(RegExp(r"'([a-z]+)'").allMatches(lessons).map((m) => m[1]), ids);
    final rules = File('../firestore.rules').readAsStringSync();
    for (final id in ids) {
      expect(rules, contains("'$id'"), reason: id);
    }
  });

  test('every question has three answers in both languages', () {
    for (final l in Lesson.all) {
      expect(l.questions, hasLength(3), reason: l.id);
      expect(l.paragraphsBn.length, l.paragraphsEn.length, reason: l.id);
      for (final q in l.questions) {
        expect(q.optionsBn, hasLength(3));
        expect(q.optionsEn, hasLength(3));
      }
    }
  });

  test('the right answer is not always shown first', () {
    final firsts = {for (var i = 0; i < 3; i++) Question.order(i).first};
    expect(firsts, containsAll([0, 1, 2]));
    for (var i = 0; i < 3; i++) {
      expect(Question.order(i).toSet(), {0, 1, 2});
    }
  });

  testWidgets('a wrong answer means trying again; all right passes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    )..setLanguage(AppLanguage.en);
    final lesson = Lesson.all.first;
    bool? passed;
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async =>
                    passed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => LessonScreen(lesson: lesson),
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take the quiz'));
    await tester.pumpAndSettle();

    // The lesson's own list; the screen under it has none.
    final list = find.byType(Scrollable).last;

    Future<void> answer(int option) async {
      // From the top: a lazy list has let go of what scrolled away.
      await tester.drag(list, const Offset(0, 4000));
      await tester.pumpAndSettle();
      for (final q in lesson.questions) {
        final f = find.text(q.optionsEn[option]);
        await tester.scrollUntilVisible(f, 200, scrollable: list);
        await tester.tap(f);
        await tester.pump();
      }
      await tester.scrollUntilVisible(
        find.text('Check answers'),
        200,
        scrollable: list,
      );
      await tester.tap(find.text('Check answers'));
      await tester.pumpAndSettle();
    }

    await answer(1);
    await tester.scrollUntilVisible(
      find.text('Try again'),
      200,
      scrollable: list,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    await answer(0);
    await tester.scrollUntilVisible(find.text('Done'), 200, scrollable: list);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(passed, isTrue);
  });
}
