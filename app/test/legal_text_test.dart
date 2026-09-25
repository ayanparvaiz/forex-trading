import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/legal/legal_text.dart';

/// The legal pages exist in two languages, and a change made to one and not
/// the other would leave Bangla readers agreeing to a different document from
/// English readers. These keep the two in step and hold the claims the stores
/// look for.
void main() {
  for (final (name, doc) in [
    ('privacy policy', privacyPolicy),
    ('terms', termsOfUse),
  ]) {
    test('$name: both languages have the same sections, line for line', () {
      final en = doc(AppLanguage.en);
      final bn = doc(AppLanguage.bn);

      expect(bn.sections.length, en.sections.length);
      for (var i = 0; i < en.sections.length; i++) {
        expect(
          bn.sections[i].lines.length,
          en.sections[i].lines.length,
          reason: en.sections[i].heading,
        );
        // A bullet in one language is a bullet in the other.
        for (var j = 0; j < en.sections[i].lines.length; j++) {
          expect(
            bn.sections[i].lines[j].startsWith('• '),
            en.sections[i].lines[j].startsWith('• '),
            reason: '${en.sections[i].heading}, line ${j + 1}',
          );
        }
      }
    });
  }

  test('the terms say what app review asks for', () {
    // Apple and Google both require apps with user content to state that
    // objectionable content is not tolerated and that users can report and
    // block. If an edit removes that, this fails before a review does.
    final terms = termsOfUse(
      AppLanguage.en,
    ).sections.expand((s) => s.lines).join(' ');
    expect(terms, contains('no tolerance for objectionable content'));
    expect(terms, contains('report'));
    expect(terms, contains('block'));
    expect(terms, contains('is financial advice'));
    expect(terms, contains('no monetary value'));
  });

  test('the privacy policy says how to delete an account', () {
    // App Store rules require in-app account deletion, and the policy has to
    // point at it.
    final policy = privacyPolicy(
      AppLanguage.en,
    ).sections.expand((s) => s.lines).join(' ');
    expect(policy, contains('Settings → Delete account'));
    // What worker/src/erase.js actually does with the name, and keeps.
    expect(policy, contains('username is retired'));
    expect(policy, contains('Reports made by you or about you may be kept'));
    expect(policy, contains('your messages in the Global chat'));
  });
}
