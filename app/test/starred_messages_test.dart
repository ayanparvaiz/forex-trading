import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/data/starred_messages.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/chat.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:forex_trading/screens/starred_messages_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stars and their messages in memory.
class FakeStarred extends StarredMessages {
  final refs = StreamController<List<StarredRef>>.broadcast();
  final messages = <String, ChatMessage?>{};
  final unstarred = <String>[];

  @override
  Stream<List<StarredRef>> watchAll(String uid) => refs.stream;

  @override
  Future<ChatMessage?> message(StarredRef ref) async => messages[ref.id];

  @override
  Future<void> unstar(
    String uid,
    String conversationId,
    String messageId,
  ) async => unstarred.add(starId(conversationId, messageId));
}

void main() {
  test('a star is kept under its conversation and message', () {
    expect(starId('c_ruetuni', 'm1'), 'c_ruetuni__m1');
  });

  testWidgets('starred messages as they are now; an unsent one says so', (
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
    final store = FakeStarred();
    final t = DateTime(2026, 9, 20, 10);
    store.messages['global__g1'] = ChatMessage(
      id: 'g1',
      senderUid: 'u-ana',
      senderName: 'Ana',
      text: 'wait for the retest',
      sentAt: t,
      unsent: false,
      pending: false,
    );
    store.messages['ana-tester__d1'] = ChatMessage(
      id: 'd1',
      senderUid: 'u-ana',
      text: '',
      sentAt: t,
      unsent: true,
      pending: false,
    );

    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: StarredMessagesScreen(store: store),
        ),
      ),
    );
    store.refs.add(const []);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing starred'), findsOneWidget);

    store.refs.add([
      StarredRef(
        conversationId: 'global',
        messageId: 'g1',
        room: true,
        starredAt: t,
      ),
      StarredRef(
        conversationId: 'ana-tester',
        messageId: 'd1',
        room: false,
        starredAt: t,
        otherUid: 'u-ana',
        otherUsername: 'ana',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Ana · Global'), findsOneWidget);
    expect(find.text('wait for the retest'), findsOneWidget);
    expect(find.text('This message is no longer available'), findsOneWidget);

    await tester.tap(find.byTooltip('Unstar').first);
    await tester.pump();
    expect(store.unstarred, ['global__g1']);
  });
}
