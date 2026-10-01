import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/models/chat.dart';

ChatMessage withReactions(Map<String, String> reactions) => ChatMessage(
  id: 'm1',
  senderUid: 'u1',
  text: 'hi',
  sentAt: DateTime(2026, 10, 1),
  unsent: false,
  pending: false,
  reactions: reactions,
);

void main() {
  test('reactions counted, most first, then in the order offered', () {
    final m = withReactions({
      'a': '😂',
      'b': '👍',
      'c': '😂',
      'd': '🔥',
      'e': '👍',
      'f': '😂',
    });
    expect(m.reactionCounts, [('😂', 3), ('👍', 2), ('🔥', 1)]);
  });

  test('ties keep the order the picker offers them in', () {
    final m = withReactions({'a': '🔥', 'b': '❤️', 'c': '👍'});
    expect([for (final (e, _) in m.reactionCounts) e], ['👍', '❤️', '🔥']);
  });

  test('six to choose from', () {
    expect(reactionEmojis, hasLength(6));
    expect(reactionEmojis.toSet(), hasLength(6));
  });
}
