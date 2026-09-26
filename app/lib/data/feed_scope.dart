import 'package:shared_preferences/shared_preferences.dart';

/// Which feed someone reads and posts to: Global, or their community's.
///
/// Remembered per account on this phone, so the feed opens where it was
/// left. A community is only ever the choice while its member is still in
/// it — after leaving, the feed is Global again.
class FeedScope {
  FeedScope({SharedPreferences? prefs}) : _injected = prefs;

  final SharedPreferences? _injected;

  static const global = 'global';

  static String _key(String uid) => 'feed_scope_$uid';

  /// [scope] if someone in [community] can still see it; Global otherwise.
  static String valid(String? scope, String? community) =>
      community != null && scope == community ? community : global;

  /// The feed [uid] last chose, if they are still in it.
  Future<String> load(String uid, String? community) async {
    try {
      final prefs = _injected ?? await SharedPreferences.getInstance();
      return valid(prefs.getString(_key(uid)), community);
    } catch (_) {
      return global;
    }
  }

  Future<void> save(String uid, String scope) async {
    try {
      final prefs = _injected ?? await SharedPreferences.getInstance();
      await prefs.setString(_key(uid), scope);
    } catch (_) {
      // Only a convenience: next time opens on Global.
    }
  }
}
