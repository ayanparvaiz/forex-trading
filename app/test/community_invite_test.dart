import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/chat.dart';

void main() {
  test('an invitation goes to the store and comes back the same', () {
    const invite = SharedCommunity(communityId: 'buetuni');
    expect(invite.toJson(), {'type': 'community', 'communityId': 'buetuni'});
    final back = MessageAttachment.fromJson(invite.toJson());
    expect(back, isA<SharedCommunity>());
    expect((back! as SharedCommunity).communityId, 'buetuni');
  });

  test('previews say what it is', () {
    expect(
      const Strings(AppLanguage.en).messagePreview('', 'community'),
      '👥 Community',
    );
    expect(
      const Strings(AppLanguage.en).messagePreview('join us', 'community'),
      '👥 Community · join us',
    );
  });
}
