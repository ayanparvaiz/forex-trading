import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/one_time_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('a notice starts undismissed and stays dismissed once read', () async {
    final notice = OneTimeNotice('ranking', prefs: prefs);

    expect(await notice.isDismissed(), isFalse);

    await notice.dismiss();
    expect(await notice.isDismissed(), isTrue);

    // A fresh instance reads the same flag — this is the case that matters,
    // since the widget holding it is rebuilt on every visit to the screen.
    expect(await OneTimeNotice('ranking', prefs: prefs).isDismissed(), isTrue);
  });

  test('notices do not read each other', () async {
    // The whole point of the id: dismissing one explanation must not silence
    // an unrelated one that has never been shown.
    await OneTimeNotice('ranking', prefs: prefs).dismiss();

    expect(await OneTimeNotice('feed', prefs: prefs).isDismissed(), isFalse);
  });

  test('reset brings a notice back', () async {
    final notice = OneTimeNotice('ranking', prefs: prefs);
    await notice.dismiss();

    await notice.reset();
    expect(await notice.isDismissed(), isFalse);
  });
}
