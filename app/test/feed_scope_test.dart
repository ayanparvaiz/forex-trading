import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/feed_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a community is the feed only while you are in it', () {
    expect(FeedScope.valid('bulls', 'bulls'), 'bulls');
    expect(FeedScope.valid('bulls', null), FeedScope.global);
    expect(FeedScope.valid('bulls', 'bears'), FeedScope.global);
    expect(FeedScope.valid(null, 'bears'), FeedScope.global);
    expect(FeedScope.valid('global', 'bears'), FeedScope.global);
  });

  test('remembered per account', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final scope = FeedScope(prefs: prefs);

    expect(await scope.load('u1', 'bulls'), FeedScope.global);
    await scope.save('u1', 'bulls');
    expect(await scope.load('u1', 'bulls'), 'bulls');
    expect(await scope.load('u2', 'bulls'), FeedScope.global);
    // Left it since: back to Global.
    expect(await scope.load('u1', null), FeedScope.global);
  });
}
