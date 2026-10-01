import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/community_repository.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    "connections only: on this phone nobody's, everyone's otherwise",
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalCommunityRepository(
        language: AppLanguage.en,
        prefs: await SharedPreferences.getInstance(),
      );
      expect((await repo.feed()).items, isNotEmpty);
      final mine = await repo.feed(connectionsOnly: true);
      expect(mine.items, isEmpty);
      expect(mine.hasMore, isFalse);
    },
  );
}
