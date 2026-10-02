import 'package:shared_preferences/shared_preferences.dart';

/// Whether the checklist comes up before each trade: on, until turned off —
/// from the checklist itself, or in settings, where it can be turned back on.
///
/// Kept on this phone, like [OneTimeNotice]: a habit of the hand holding it.
class TradeChecklistPref {
  TradeChecklistPref({SharedPreferences? prefs}) : _injected = prefs;

  static const _key = 'trade.checklist';

  final SharedPreferences? _injected;
  SharedPreferences? _cached;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  Future<bool> isOn() async => (await _prefs).getBool(_key) ?? true;

  Future<void> set(bool on) async => (await _prefs).setBool(_key, on);
}
