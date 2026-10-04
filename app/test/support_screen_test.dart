import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/data/support_repository.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/support_message.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/support_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSupport implements SupportSource {
  final mine = StreamController<List<SupportMessage>>.broadcast();
  final sent = <(String, String, String)>[];
  String? watched;

  @override
  Stream<List<SupportMessage>> watchMine(String uid) {
    watched = uid;
    return mine.stream;
  }

  @override
  Future<void> send({
    required String uid,
    required String username,
    required String text,
  }) async => sent.add((uid, username, text));
}

void main() {
  testWidgets('write to the admins, and read their answer when it comes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthRepository(
      prefs: await SharedPreferences.getInstance(),
    );
    await auth.signUp(
      username: 'tester',
      password: 'secret123',
      displayName: 'Tester',
      gender: Gender.male,
      language: AppLanguage.en,
      avatarId: 1,
    );
    final session = SessionController(auth);
    await session.restore();
    final source = FakeSupport();
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: SupportScreen(source: source),
        ),
      ),
    );
    await tester.pump();
    expect(source.watched, session.uid);
    source.mine.add(const []);
    await tester.pump();
    expect(find.text('Nothing written yet.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  How do I start over?  ');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(source.sent, [(session.uid!, 'tester', 'How do I start over?')]);
    expect(
      find.text('Sent. The admins will read it and answer.'),
      findsOneWidget,
    );

    source.mine.add([
      SupportMessage(id: 's2', text: 'And my streak?', sentAt: DateTime.now()),
      SupportMessage(
        id: 's1',
        text: 'How do I start over?',
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'answered',
        reply: 'Settings → Journal → Start over.',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Waiting for an answer'), findsOneWidget);
    expect(find.text('The admins answered'), findsOneWidget);
    expect(find.text('Settings → Journal → Start over.'), findsOneWidget);
  });
}
