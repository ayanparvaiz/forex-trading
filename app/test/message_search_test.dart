import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/chat.dart';
import 'package:forex_trading/screens/message_search_screen.dart';
import 'package:forex_trading/theme/app_theme.dart';
import 'package:forex_trading/widgets/conversation_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [all] messages, oldest first, served newest first a page at a time —
/// the cursor is where the page before starts.
class PagedSource implements MessageSource {
  PagedSource(this.all);

  final List<ChatMessage> all;
  int pagesRead = 0;

  @override
  String get prefsId => 'paged';

  @override
  int get pageSize => 30;

  List<ChatMessage> _pageEndingAt(int end) {
    pagesRead++;
    final start = (end - pageSize).clamp(0, end);
    return [
      for (var i = end - 1; i >= start; i--)
        ChatMessage(
          id: all[i].id,
          senderUid: all[i].senderUid,
          text: all[i].text,
          sentAt: all[i].sentAt,
          unsent: all[i].unsent,
          pending: false,
          attachment: all[i].attachment,
          cursor: i,
        ),
    ];
  }

  @override
  Stream<List<ChatMessage>> watchLatest() =>
      Stream.value(_pageEndingAt(all.length));

  @override
  Future<List<ChatMessage>> olderThan(Object cursor) async =>
      _pageEndingAt(cursor as int);

  @override
  Future<ChatMessage?> message(String id) async => null;

  @override
  Future<void> send(String text, {ReplyRef? replyTo}) async {}

  @override
  Future<void> unsend(ChatMessage m, {required bool isLatest}) async {}

  @override
  Future<void> react(ChatMessage m, String? emoji) async {}

  @override
  Future<void> vote(ChatMessage m, int? option) async {}
}

void main() {
  final t0 = DateTime(2026, 9, 1, 9);

  ChatMessage msg(int i, String text, {MessageAttachment? attachment}) =>
      ChatMessage(
        id: 'm$i',
        senderUid: i.isEven ? 'ana' : 'bo',
        text: text,
        sentAt: t0.add(Duration(minutes: i)),
        unsent: false,
        pending: false,
        attachment: attachment,
      );

  Future<List<String?>> open(
    WidgetTester tester,
    PagedSource source, {
    bool Function(ChatMessage m)? shows,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionController(
      LocalAuthRepository(prefs: await SharedPreferences.getInstance()),
    )..setLanguage(AppLanguage.en);
    final picked = <String?>[];
    await tester.pumpWidget(
      SessionScope(
        controller: session,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => picked.add(
                  await searchMessages(
                    context,
                    source: source,
                    nameOf: (uid, m) => uid == 'ana' ? 'Ana' : 'Bo',
                    shows: shows,
                  ),
                ),
                child: const Text('search'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('search'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('finds the words, newest first, and picks one', (tester) async {
    final source = PagedSource([
      for (var i = 0; i < 40; i++)
        msg(i, i % 10 == 3 ? 'waited for the RETEST at $i' : 'hello $i'),
    ]);
    final picked = await open(tester, source);
    expect(find.textContaining('Type a word'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'retest');
    await tester.pump();
    // 3, 13, 23 and 33 — the newest on top.
    expect(find.byType(ListTile), findsNWidgets(4));
    expect(
      tester.getTopLeft(find.textContaining('at 33')).dy,
      lessThan(
        tester
            .getTopLeft(find.textContaining('at 3', findRichText: true).last)
            .dy,
      ),
    );
    expect(find.text('Searched the whole conversation'), findsOneWidget);

    await tester.tap(find.textContaining('at 13', findRichText: true));
    await tester.pumpAndSettle();
    expect(picked, ['m13']);
  });

  testWidgets('a few hundred at a time; further back when asked', (
    tester,
  ) async {
    final source = PagedSource([
      msg(0, 'the very first breakout'),
      for (var i = 1; i < 400; i++) msg(i, 'nothing here $i'),
    ]);
    final picked = await open(tester, source);
    final firstRead = source.pagesRead;
    expect(firstRead, 10, reason: '300 messages, 30 a page');

    await tester.enterText(find.byType(TextField), 'breakout');
    await tester.pump();
    expect(find.text('Nothing found'), findsOneWidget);
    expect(source.pagesRead, firstRead, reason: 'typing reads nothing');
    expect(find.text('Searched the last 300 messages'), findsOneWidget);

    await tester.tap(find.text('Look further back'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing found'), findsNothing);
    expect(find.text('Searched the whole conversation'), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(picked, ['m0']);
  });

  testWidgets("a poll's question is found; what I deleted is not", (
    tester,
  ) async {
    final source = PagedSource([
      msg(
        0,
        '',
        attachment: const Poll(
          question: 'Which pair this week?',
          options: ['EURUSD', 'GBPUSD'],
        ),
      ),
      msg(1, 'which pair do you like'),
      msg(2, 'which pair, again'),
    ]);
    await open(tester, source, shows: (m) => m.id != 'm2');
    await tester.enterText(find.byType(TextField), 'which pair');
    await tester.pump();
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.textContaining('again', findRichText: true), findsNothing);
  });
}
