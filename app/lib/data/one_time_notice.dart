import 'package:shared_preferences/shared_preferences.dart';

/// A notice that is shown until the reader says they have read it.
///
/// Explanations of how something works are worth saying once and then getting
/// out of the way. A panel that reappears on every visit stops being read after
/// the second time and starts being scrolled past, which costs the screen its
/// space and teaches people to ignore the next panel too.
///
/// Kept on the device, like [SeenPosts]: having read an explanation is a fact
/// about this phone, not about the account, and the worst case of losing it is
/// reading a short paragraph again.
class OneTimeNotice {
  OneTimeNotice(this.id, {SharedPreferences? prefs}) : _injected = prefs;

  /// Stable per notice. Changing it brings the notice back for everyone, which
  /// is the right behaviour when the text itself has changed enough to be
  /// worth re-reading.
  final String id;

  final SharedPreferences? _injected;
  SharedPreferences? _cached;

  String get _key => 'notice.$id';

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  Future<bool> isDismissed() async => (await _prefs).getBool(_key) ?? false;

  Future<void> dismiss() async => (await _prefs).setBool(_key, true);

  Future<void> reset() async => (await _prefs).remove(_key);
}
