import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trade.dart';

/// The daily loss limit: once today's closed trades have lost this share of
/// the day's points, no more trades until midnight.
///
/// Set in a calm moment, for the moment that is not: so a stricter limit
/// counts at once, and a looser one — or none — only from tomorrow. Nobody
/// talks themselves out of it mid-tilt.
class LossLimit extends ChangeNotifier {
  LossLimit({SharedPreferences? prefs, DateTime Function()? clock})
    : _injected = prefs,
      _clock = clock ?? DateTime.now;

  /// The limits on offer, in percent of the day's points; 0 for none.
  static const choices = [0, 2, 3, 5];

  static const _keyNow = 'lossLimit.now';
  static const _keyNext = 'lossLimit.next';
  static const _keyFrom = 'lossLimit.from';

  final SharedPreferences? _injected;
  final DateTime Function() _clock;
  SharedPreferences? _cached;
  bool _loaded = false;

  int _now = 0;
  int? _next;
  DateTime? _from;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  /// The limit in force today, in percent; 0 when there is none.
  int get percent {
    final next = _next, from = _from;
    if (next != null && from != null && !_clock().isBefore(from)) return next;
    return _now;
  }

  /// A looser limit waiting for tomorrow, if one is.
  int? get pending {
    final next = _next, from = _from;
    if (next == null || from == null || !_clock().isBefore(from)) return null;
    return next;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final p = await _prefs;
    _now = p.getInt(_keyNow) ?? 0;
    _next = p.getInt(_keyNext);
    final from = p.getString(_keyFrom);
    _from = from == null ? null : DateTime.tryParse(from);
    notifyListeners();
  }

  /// Sets the limit to [to]: at once when stricter, from midnight when not.
  Future<void> set(int to) async {
    await load();
    final current = percent;
    final stricter = to != 0 && (current == 0 || to < current);
    final now = _clock();
    if (stricter || to == current) {
      _now = to;
      _next = null;
      _from = null;
    } else {
      _now = current;
      _next = to;
      _from = DateTime(now.year, now.month, now.day + 1);
    }
    notifyListeners();
    final p = await _prefs;
    await p.setInt(_keyNow, _now);
    if (_next == null) {
      await p.remove(_keyNext);
      await p.remove(_keyFrom);
    } else {
      await p.setInt(_keyNext, _next!);
      await p.setString(_keyFrom, _from!.toIso8601String());
    }
  }
}

/// What today's closed trades have lost, as a percent of [dayPoints]; 0 when
/// they are ahead.
double lossTodayPercent(List<Trade> todaysClosed, double dayPoints) {
  final pnl = todaysClosed.fold<double>(0, (s, t) => s + (t.realisedPnl ?? 0));
  return pnl >= 0 || dayPoints <= 0 ? 0 : -pnl / dayPoints * 100;
}

/// The app's one.
final lossLimit = LossLimit();
