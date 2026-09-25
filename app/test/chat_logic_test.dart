import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/chat.dart';

/// The parts of messaging that decide what people see — ticks, presence,
/// which messages are on screen, which arrivals get a banner — are plain
/// functions, so they are tested as plain functions.
void main() {
  const me = 'me';
  const them = 'them';
  final t0 = DateTime.utc(2026, 9, 25, 10);

  ChatThread thread({
    DateTime? theirRead,
    DateTime? theirDelivered,
    Map<String, int> unread = const {},
  }) => ChatThread(
    id: 'a-b',
    uids: const [me, them],
    users: const ['a', 'b'],
    updatedAt: t0,
    lastMessage: null,
    unread: unread,
    readAt: {them: ?theirRead},
    deliveredAt: {them: ?theirDelivered},
  );

  ChatMessage msg(
    String id,
    DateTime at, {
    String from = me,
    bool pending = false,
    bool unsent = false,
    String text = 'hi',
  }) => ChatMessage(
    id: id,
    senderUid: from,
    text: text,
    sentAt: at,
    unsent: unsent,
    pending: pending,
  );

  group('ticks', () {
    test('a message still on this phone shows a clock', () {
      expect(
        statusOf(msg('1', t0, pending: true), thread(theirRead: t0), me),
        MessageStatus.pending,
      );
    });

    test('on the server, not yet received: one tick', () {
      expect(
        statusOf(
          msg('1', t0),
          thread(theirDelivered: t0.subtract(const Duration(minutes: 1))),
          me,
        ),
        MessageStatus.sent,
      );
    });

    test('received but not opened: two grey ticks', () {
      final m = msg('1', t0);
      expect(
        statusOf(
          m,
          thread(
            theirDelivered: t0.add(const Duration(seconds: 5)),
            theirRead: t0.subtract(const Duration(minutes: 1)),
          ),
          me,
        ),
        MessageStatus.delivered,
      );
    });

    test(
      'opened since it was sent: blue — and a mark at the same instant counts',
      () {
        expect(
          statusOf(msg('1', t0), thread(theirRead: t0), me),
          MessageStatus.read,
        );
      },
    );

    test('one mark covers every message before it', () {
      // Marks, not per-message flags: everything up to the mark is read at
      // once, which is also what WhatsApp shows.
      final th = thread(theirRead: t0.add(const Duration(minutes: 10)));
      for (var i = 0; i < 5; i++) {
        expect(
          statusOf(msg('$i', t0.add(Duration(minutes: i))), th, me),
          MessageStatus.read,
        );
      }
      expect(
        statusOf(msg('late', t0.add(const Duration(minutes: 11))), th, me),
        MessageStatus.sent,
      );
    });
  });

  group('presence', () {
    test('no heartbeat ever: unknown', () {
      expect(presenceOf(null, t0), Presence.unknown);
    });

    test('within two and a half minutes of a beat: active now', () {
      expect(
        presenceOf(t0.subtract(const Duration(seconds: 150)), t0),
        Presence.activeNow,
      );
    });

    test('a missed beat or two later: recently, with a time', () {
      expect(
        presenceOf(t0.subtract(const Duration(seconds: 151)), t0),
        Presence.recently,
      );
    });
  });

  group('typing', () {
    ChatThread typingAt(DateTime? at) => ChatThread(
      id: 'a-b',
      uids: const [me, them],
      users: const ['a', 'b'],
      updatedAt: t0,
      lastMessage: null,
      unread: const {},
      readAt: const {},
      deliveredAt: const {},
      typing: {them: ?at},
    );

    test('a fresh mark: typing', () {
      expect(
        isTyping(typingAt(t0.subtract(const Duration(seconds: 2))), them, t0),
        isTrue,
      );
    });

    test('a mark older than the window: stopped, even if never cleared', () {
      // Someone who puts the phone down mid-sentence never sends the clear.
      expect(
        isTyping(typingAt(t0.subtract(const Duration(seconds: 9))), them, t0),
        isFalse,
      );
    });

    test('no mark, or a mark for someone else: not typing', () {
      expect(isTyping(typingAt(null), them, t0), isFalse);
      expect(isTyping(typingAt(t0), me, t0), isFalse);
    });

    test('a clock a second or two ahead still reads as typing', () {
      expect(
        isTyping(typingAt(t0.add(const Duration(seconds: 2))), them, t0),
        isTrue,
      );
    });

    test('refreshes land well inside the window', () {
      // The typist re-stamps every few seconds; if that were not comfortably
      // shorter than the window, "typing…" would flicker between refreshes.
      expect(typingRefresh * 2, lessThan(typingWindow));
    });
  });

  group('loading messages', () {
    test('newest first, merged without duplicates', () {
      final a = msg('a', t0);
      final b = msg('b', t0.add(const Duration(minutes: 1)));
      final c = msg('c', t0.add(const Duration(minutes: 2)));

      final merged = mergeMessages([a, b], [b, c]);
      expect(merged.map((m) => m.id), ['c', 'b', 'a']);
    });

    test('a message that slides out of the live window is kept', () {
      // The live page is the newest thirty. When a new one arrives the
      // oldest drops out of it — but it still exists and is still on screen.
      final loaded = [
        for (var i = 0; i < 30; i++) msg('$i', t0.add(Duration(minutes: i))),
      ];
      final window = [
        for (var i = 1; i <= 30; i++) msg('$i', t0.add(Duration(minutes: i))),
      ];

      final merged = mergeMessages(loaded, window);
      expect(merged, hasLength(31));
      expect(merged.last.id, '0');
    });

    test('an unsent message replaces the original in place', () {
      final original = msg('x', t0, text: 'oops');
      final unsent = msg('x', t0, text: '', unsent: true);

      final merged = mergeMessages([original], [unsent]);
      expect(merged.single.unsent, isTrue);
      expect(merged.single.text, isEmpty);
    });

    test('a pending message turns into a sent one without doubling', () {
      final pending = msg('p', t0, pending: true);
      final confirmed = msg('p', t0.add(const Duration(milliseconds: 80)));

      final merged = mergeMessages([pending], [confirmed]);
      expect(merged.single.pending, isFalse);
    });
  });

  group('banners', () {
    ChatThread withLast(
      String chatId,
      String msgId,
      String from, {
      bool unsent = false,
    }) => ChatThread(
      id: chatId,
      uids: const [me, them],
      users: const ['a', 'b'],
      updatedAt: t0,
      lastMessage: ChatPreview(
        id: msgId,
        senderUid: from,
        text: 'hello',
        unsent: unsent,
        sentAt: t0,
      ),
      unread: const {},
      readAt: const {},
      deliveredAt: const {},
    );

    test('the first snapshot announces nothing', () {
      expect(
        newArrivals(
          before: null,
          now: [withLast('c1', 'm1', them)],
          me: me,
          openChatId: null,
        ),
        isEmpty,
      );
    });

    test('a new message from them, in another chat: a banner', () {
      final got = newArrivals(
        before: {'c1': 'm1'},
        now: [withLast('c1', 'm2', them)],
        me: me,
        openChatId: 'c9',
      );
      expect(got.map((t) => t.id), ['c1']);
    });

    test('in the chat already open: no banner', () {
      expect(
        newArrivals(
          before: {'c1': 'm1'},
          now: [withLast('c1', 'm2', them)],
          me: me,
          openChatId: 'c1',
        ),
        isEmpty,
      );
    });

    test('my own message, an unchanged one, or an unsend: no banner', () {
      expect(
        newArrivals(
          before: {'c1': 'm1'},
          now: [withLast('c1', 'm2', me)],
          me: me,
          openChatId: null,
        ),
        isEmpty,
      );
      expect(
        newArrivals(
          before: {'c1': 'm1'},
          now: [withLast('c1', 'm1', them)],
          me: me,
          openChatId: null,
        ),
        isEmpty,
      );
      expect(
        newArrivals(
          before: {'c1': 'm1'},
          now: [withLast('c1', 'm2', them, unsent: true)],
          me: me,
          openChatId: null,
        ),
        isEmpty,
      );
    });

    test('a brand-new conversation with a message: a banner', () {
      final got = newArrivals(
        before: {'c1': 'm1'},
        now: [withLast('c1', 'm1', them), withLast('c2', 'n1', them)],
        me: me,
        openChatId: null,
      );
      expect(got.map((t) => t.id), ['c2']);
    });
  });

  group('deleting for me', () {
    final cleared = t0.add(const Duration(minutes: 10));
    final prefs = ChatPrefs(clearedAt: cleared, hidden: const {'h'});

    test('a message deleted for me is left out, and only that one', () {
      final m1 = msg('h', t0.add(const Duration(minutes: 20)));
      final m2 = msg('k', t0.add(const Duration(minutes: 20)));
      expect(prefs.shows(m1), isFalse);
      expect(prefs.shows(m2), isTrue);
    });

    test('a deleted chat hides everything up to the moment of deleting', () {
      expect(prefs.shows(msg('1', t0)), isFalse);
      expect(prefs.shows(msg('2', cleared)), isFalse);
      expect(
        prefs.shows(msg('3', cleared.add(const Duration(seconds: 1)))),
        isTrue,
      );
    });

    test(
      'a message still on its way is new, whatever its placeholder time',
      () {
        expect(prefs.shows(msg('p', t0, pending: true)), isTrue);
      },
    );

    test('a deleted chat leaves the inbox until something new is said', () {
      ChatThread at(DateTime t) => ChatThread(
        id: 'a-b',
        uids: const [me, them],
        users: const ['a', 'b'],
        updatedAt: t,
        lastMessage: null,
        unread: const {},
        readAt: const {},
        deliveredAt: const {},
      );
      expect(prefs.listsThread(at(cleared)), isFalse);
      expect(
        prefs.listsThread(at(cleared.add(const Duration(seconds: 1)))),
        isTrue,
      );
      expect(ChatPrefs.none.listsThread(at(t0)), isTrue);
    });

    test('nothing older is worth loading once the page reaches the clear', () {
      expect(prefs.clearedBy(t0), isTrue);
      expect(prefs.clearedBy(cleared.add(const Duration(minutes: 1))), isFalse);
      expect(ChatPrefs.none.clearedBy(t0), isFalse);
    });
  });

  group('time labels', () {
    const en = Strings(AppLanguage.en);
    const bn = Strings(AppLanguage.bn);
    final now = DateTime(2026, 9, 25, 15, 30); // a Friday

    test('twelve-hour clock', () {
      expect(en.clock(DateTime(2026, 9, 25, 0, 5)), '12:05 AM');
      expect(en.clock(DateTime(2026, 9, 25, 12, 0)), '12:00 PM');
      expect(en.clock(DateTime(2026, 9, 25, 22, 24)), '10:24 PM');
    });

    test('day separators', () {
      expect(en.dayLabel(DateTime(2026, 9, 25, 1), now), 'Today');
      expect(en.dayLabel(DateTime(2026, 9, 24, 23), now), 'Yesterday');
      expect(en.dayLabel(DateTime(2026, 9, 22), now), 'Tue');
      expect(en.dayLabel(DateTime(2026, 9, 10), now), '10 Sep');
      expect(bn.dayLabel(DateTime(2026, 9, 24), now), 'গতকাল');
    });

    test('inbox row: a clock today, a word after', () {
      expect(en.threadTime(DateTime(2026, 9, 25, 9, 7), now), '9:07 AM');
      expect(en.threadTime(DateTime(2026, 9, 24, 9, 7), now), 'Yesterday');
    });

    test('last active', () {
      expect(
        en.activeAgo(now.subtract(const Duration(seconds: 200)), now),
        'Active 3m ago',
      );
      expect(
        en.activeAgo(now.subtract(const Duration(hours: 5)), now),
        'Active 5h ago',
      );
      expect(
        en.activeAgo(now.subtract(const Duration(days: 1, hours: 2)), now),
        'Active yesterday',
      );
      expect(
        bn.activeAgo(now.subtract(const Duration(minutes: 7)), now),
        '7 মিনিট আগে অ্যাক্টিভ',
      );
    });
  });
}
