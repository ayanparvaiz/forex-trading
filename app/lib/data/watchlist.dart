import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/instrument.dart';

/// The pairs a trader keeps an eye on: starred on the trade screen, listed
/// with their prices on the portfolio.
///
/// Kept on this phone: it is where the practice market runs, and losing it
/// costs no more than a few taps.
class Watchlist extends ChangeNotifier {
  Watchlist({SharedPreferences? prefs}) : _injected = prefs;

  static const _key = 'watchlist';

  final SharedPreferences? _injected;
  SharedPreferences? _cached;
  bool _loaded = false;

  /// Symbols, in the order they were starred.
  List<String> _symbols = const [];

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  /// Reads what was starred before, once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final saved = (await _prefs).getStringList(_key) ?? const [];
    _symbols = [
      for (final s in saved)
        if (Instrument.all.any((i) => i.symbol == s)) s,
    ];
    notifyListeners();
  }

  /// The starred pairs, in the order they were starred.
  List<Instrument> get pairs => [
    for (final s in _symbols) Instrument.bySymbol(s),
  ];

  bool contains(Instrument i) => _symbols.contains(i.symbol);

  Future<void> toggle(Instrument i) async {
    _symbols = contains(i)
        ? [
            for (final s in _symbols)
              if (s != i.symbol) s,
          ]
        : [..._symbols, i.symbol];
    notifyListeners();
    await (await _prefs).setStringList(_key, _symbols);
  }

  /// [all] with the starred ones first, each group in its own order.
  List<Instrument> starredFirst(List<Instrument> all) => [
    ...all.where(contains),
    ...all.where((i) => !contains(i)),
  ];
}

/// The app's watchlist.
final watchlist = Watchlist();
