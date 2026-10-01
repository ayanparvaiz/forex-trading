import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/models/mentions.dart';

void main() {
  test('names in a message, the way the worker finds them', () {
    List<String> names(String t) => [
      for (final m in mentionPattern.allMatches(t)) m[1]!.toLowerCase(),
    ];
    expect(names('@ana look at this, @Bobby'), ['ana', 'bobby']);
    expect(names('mail me at me@ana.com'), isEmpty);
    expect(names('@ab is too short'), isEmpty);
    expect(names('(@tahmid_h) thanks'), ['tahmid_h']);
  });

  test('the @name being typed', () {
    expect(mentionAt('hi @ta', 6), (3, 'ta'));
    expect(mentionAt('@', 1), (0, ''));
    expect(mentionAt('hi @Ta', 6), (3, 'ta'));
    expect(mentionAt('hi ta', 5), isNull);
    expect(mentionAt('me@ana', 6), isNull, reason: 'an address');
    expect(mentionAt('hi @tahmid now', 14), isNull, reason: 'past it');
  });

  test('completing one puts the whole name and a space, cursor after', () {
    expect(completeMention('hi @ta', 3, 6, 'tahmid_h'), ('hi @tahmid_h ', 13));
    expect(completeMention('@na and more', 0, 3, 'nafisa_r'), (
      '@nafisa_r  and more',
      10,
    ));
  });
}
