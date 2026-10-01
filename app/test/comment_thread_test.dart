import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/models/post_comment.dart';

PostComment c(String id, {String? replyTo}) => PostComment(
  id: id,
  authorUsername: id,
  authorName: id,
  authorAvatarId: 1,
  body: id,
  createdAt: DateTime(2026, 10, 1),
  replyTo: replyTo == null
      ? null
      : CommentReply(id: replyTo, authorUid: 'u', name: replyTo),
);

void main() {
  test('replies sit under their comment, one level deep', () {
    final thread = threadComments([
      c('a'),
      c('b'),
      c('a1', replyTo: 'a'),
      c('a1x', replyTo: 'a1'), // a reply to a reply: still under a
      c('b1', replyTo: 'b'),
      c('orphan', replyTo: 'gone'),
    ]);
    expect([for (final (x, reply) in thread) '${x.id}${reply ? '↳' : ''}'], [
      'a',
      'a1↳',
      'a1x↳',
      'b',
      'b1↳',
      'orphan',
    ]);
  });
}
