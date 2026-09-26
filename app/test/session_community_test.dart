import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/auth_repository.dart';
import 'package:forex_trading/data/session_controller.dart';
import 'package:forex_trading/i18n/strings.dart';
import 'package:forex_trading/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On this phone, but with the profile's community moved by someone else —
/// as an admin removing you, or deleting it, does.
class _MovedElsewhere extends LocalAuthRepository {
  _MovedElsewhere(SharedPreferences prefs) : super(prefs: prefs);

  final community = StreamController<String?>.broadcast();

  @override
  Stream<String?> watchCommunityId(String uid) => community.stream;
}

void main() {
  test('the session follows the community its profile is in', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = _MovedElsewhere(await SharedPreferences.getInstance());
    await auth.signUp(
      username: 'rifat',
      password: 'secret123',
      displayName: 'Rifat Hasan',
      gender: Gender.male,
      language: AppLanguage.en,
      avatarId: 1,
    );
    final session = SessionController(auth);
    await session.restore();
    expect(session.profile?.communityId, isNull);

    auth.community.add('bulls1');
    await pumpEventQueue();
    expect(session.profile?.communityId, 'bulls1');

    // Removed, or the community deleted: out of it at once.
    auth.community.add(null);
    await pumpEventQueue();
    expect(session.profile?.communityId, isNull);

    // Signed out: nothing more is heard.
    await session.logOut();
    expect(auth.community.hasListener, isFalse);
  });
}
