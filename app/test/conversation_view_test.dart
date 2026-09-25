import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/chat.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/conversation_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A conversation held in memory, recording what the view asks of it.
class FakeSource implements MessageSource {
  final latest = StreamController<List<ChatMessage>>.broadcast();
  final Map<String, ChatMessage> elsewhere = {};
  final sent = <(String, ReplyRef?)>[];
  final unsent = <(String, bool)>[];

  @override
  String get prefsId => 'fake';

  @override
  int get pageSize => 30;

  @override
  Stream<List<ChatMessage>> watchLatest() => latest.stream;

  @override
  Future<List<ChatMessage>> olderThan(Object cursor) async => const [];

  @override
  Future<ChatMessage?> message(String id) async => elsewhere[id];

  @override
  Future<void> send(String text, {ReplyRef? replyTo}) async =>
      sent.add((text, replyTo));

  @override
  Future<void> unsend(ChatMessage m, {required bool isLatest}) async =>
      unsent.add((m.id, isLatest));
}

void main() {
  const me = 'me';
  final t0 = DateTime(2026, 9, 25, 10);

  ChatMessage msg(
    String id,
    int minute, {
    String from = me,
    String text = 'hi',
    ReplyRef? replyTo,
  }) => ChatMessage(
    id: id,
    senderUid: from,
    text: text,
    sentAt: t0.add(Duration(minutes: minute)),
    unsent: false,
    pending: false,
    replyTo: replyTo,
  );

  Future<FakeSource> pump(
    WidgetTester tester, {
    bool canSend = true,
    bool showSenderNames = false,
    Widget? bottom,
    ValueChanged<ChatMessage>? onOpenSender,
    ValueChanged<String>? onOpenPost,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    )..setLanguage(AppLanguage.en);
    final source = FakeSource();
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ConversationView(
              source: source,
              me: me,
              canSend: canSend,
              nameOf: (uid, m) => uid == me ? 'You' : (m?.senderName ?? 'Ana'),
              emptyText: 'Say hi',
              showSenderNames: showSenderNames,
              bottom: bottom,
              onOpenSender: onOpenSender,
              onOpenPost: onOpenPost,
            ),
          ),
        ),
      ),
    );
    return source;
  }

  testWidgets('nothing yet says so', (tester) async {
    final source = await pump(tester);
    source.latest.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('Say hi'), findsOneWidget);
  });

  testWidgets('swipe to reply, then the reply names its original', (
    tester,
  ) async {
    final source = await pump(tester);
    source.latest.add([msg('m1', 0, from: 'ana', text: 'EUR/USD long?')]);
    await tester.pumpAndSettle();

    await tester.drag(
      find.textContaining('EUR/USD long?'),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    // The strip over the box quotes it, under the sender's name.
    expect(find.text('Ana'), findsOneWidget);
    expect(find.textContaining('EUR/USD long?'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'wait for the retest');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(source.sent, hasLength(1));
    expect(source.sent.single.$1, 'wait for the retest');
    expect(source.sent.single.$2?.id, 'm1');
    expect(source.sent.single.$2?.senderUid, 'ana');
    // The strip goes once it is sent.
    expect(find.textContaining('EUR/USD long?'), findsOneWidget);
  });

  testWidgets('a quote whose original is not loaded is fetched', (
    tester,
  ) async {
    final source = await pump(tester);
    source.elsewhere['old'] = msg(
      'old',
      -600,
      from: 'ana',
      text: 'from ages ago',
    );
    source.latest.add([
      msg(
        'r1',
        0,
        text: 'agreed',
        replyTo: const ReplyRef(id: 'old', senderUid: 'ana'),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('from ages ago'), findsOneWidget);
    expect(find.textContaining('agreed'), findsOneWidget);
  });

  testWidgets('no box and no replying where you cannot send', (tester) async {
    final source = await pump(
      tester,
      canSend: false,
      bottom: const Text('join to write'),
    );
    source.latest.add([msg('m1', 0, from: 'ana', text: 'hello all')]);
    await tester.pumpAndSettle();
    expect(find.text('join to write'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.longPress(find.textContaining('hello all'));
    await tester.pumpAndSettle();
    expect(find.text('Reply'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('in a room, a run of messages starts with its sender', (
    tester,
  ) async {
    final source = await pump(tester, showSenderNames: true);
    ChatMessage from(String id, int minute, String uid, String name) =>
        ChatMessage(
          id: id,
          senderUid: uid,
          senderName: name,
          text: 'msg $id',
          sentAt: t0.add(Duration(minutes: minute)),
          unsent: false,
          pending: false,
        );
    source.latest.add([
      from('c', 2, 'bo', 'Bo'),
      from('b', 1, 'ana', 'Ana'),
      from('a', 0, 'ana', 'Ana'),
    ]);
    await tester.pumpAndSettle();
    // One name per run, not per message.
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
  });

  testWidgets('unsending the newest message says it is the newest', (
    tester,
  ) async {
    final source = await pump(tester);
    source.latest.add([msg('m2', 1, text: 'oops'), msg('m1', 0, text: 'fine')]);
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('oops'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unsend'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Unsend'));
    await tester.pumpAndSettle();

    expect(source.unsent, [('m2', true)]);
  });

  testWidgets('a shared rank is a card that opens its sender', (tester) async {
    ChatMessage? opened;
    final source = await pump(tester, onOpenSender: (m) => opened = m);
    source.latest.add([
      ChatMessage(
        id: 'r1',
        senderUid: 'ana',
        text: '',
        sentAt: t0,
        unsent: false,
        pending: false,
        attachment: const SharedRank(rank: 4, score: 92),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('#4 on the board'), findsOneWidget);
    expect(find.textContaining('Discipline 92'), findsOneWidget);

    await tester.tap(find.text('#4 on the board'));
    expect(opened?.id, 'r1');

    // With no words to copy, there is no Copy.
    await tester.longPress(find.text('#4 on the board'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Forward'), findsNothing); // no inbox in this test
  });

  testWidgets('a shared post that is gone says so, and does not open', (
    tester,
  ) async {
    String? opened;
    final source = await pump(tester, onOpenPost: (id) => opened = id);
    source.latest.add([
      ChatMessage(
        id: 'p1',
        senderUid: 'ana',
        text: 'look',
        sentAt: t0,
        unsent: false,
        pending: false,
        attachment: const SharedPost(postId: 'no-such-post', authorUid: 'x'),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('This post is no longer available'), findsOneWidget);
    await tester.tap(find.text('This post is no longer available'));
    expect(opened, isNull);
  });

  testWidgets('replying to a card quotes what it was', (tester) async {
    final source = await pump(tester);
    source.latest.add([
      ChatMessage(
        id: 'r1',
        senderUid: 'ana',
        text: '',
        sentAt: t0,
        unsent: false,
        pending: false,
        attachment: const SharedRank(rank: 2, score: 95),
      ),
    ]);
    await tester.pumpAndSettle();
    await tester.drag(find.text('#2 on the board'), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(find.text('🏅 Leaderboard rank'), findsOneWidget);
  });
}
