import 'package:shared_preferences/shared_preferences.dart';

/// Which posts this device has already shown.
///
/// Kept on the device rather than in Firestore. Seen-ness is a reading
/// convenience, not a fact about the account: it costs nothing here, needs no
/// query to read back, and the worst case of losing it is seeing a good post
/// twice. Storing it server-side would mean a read and a write per post
/// scrolled past, for that.
class SeenPosts {
  SeenPosts({SharedPreferences? prefs}) : _injected = prefs;

  final SharedPreferences? _injected;
  SharedPreferences? _cached;
  Set<String>? _ids;

  static const _key = 'feed.seen';

  /// How many ids to remember.
  ///
  /// Bounded so the list cannot grow forever on a heavy reader. Falling off the
  /// end just means an old post could surface again, which after a few hundred
  /// posts is no loss at all.
  static const _limit = 400;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  Future<Set<String>> load() async {
    final cached = _ids;
    if (cached != null) return cached;

    return _ids = (await _prefs).getStringList(_key)?.toSet() ?? <String>{};
  }

  /// Records [ids] as shown. Returns once the write is durable.
  Future<void> add(Iterable<String> ids) async {
    final current = await load();
    final before = current.length;
    current.addAll(ids);
    if (current.length == before) return;

    // Oldest entries fall off the front. Order is insertion order, which is
    // close enough to "least recently seen" for a list whose only job is to
    // push repeats down.
    final trimmed = current.length > _limit
        ? current.skip(current.length - _limit).toSet()
        : current;

    _ids = trimmed;
    await (await _prefs).setStringList(_key, trimmed.toList());
  }

  Future<void> clear() async {
    _ids = <String>{};
    await (await _prefs).remove(_key);
  }
}
