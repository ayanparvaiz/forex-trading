import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Tell me when EUR/USD reaches 1.14200."
class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.symbol,
    required this.price,
    required this.above,
  });

  final String id;
  final String symbol;
  final double price;

  /// Set from above the price (rings on the way down) or below it (on the
  /// way up) — whichever side the market was on when it was made.
  final bool above;

  bool reachedAt(double now) => above ? now >= price : now <= price;

  Map<String, Object> toJson() => {
    'id': id,
    'symbol': symbol,
    'price': price,
    'above': above,
  };

  static PriceAlert? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], symbol = json['symbol'], price = json['price'];
    if (id is! String || symbol is! String || price is! num) return null;
    return PriceAlert(
      id: id,
      symbol: symbol,
      price: price.toDouble(),
      above: json['above'] == true,
    );
  }
}

/// Price alerts, on this phone and per account — the practice market runs
/// here, so this is where its prices are watched.
class PriceAlerts extends ChangeNotifier {
  PriceAlerts({SharedPreferences? prefs}) : _injected = prefs;

  final SharedPreferences? _injected;
  String? _owner;
  List<PriceAlert> _alerts = const [];

  /// Most alerts at once: enough to watch every pair both ways, and then
  /// some, without a list to manage.
  static const max = 10;

  List<PriceAlert> get alerts => _alerts;

  final _rang = StreamController<PriceAlert>.broadcast();

  /// Each alert as it rings — once, and then it is gone.
  Stream<PriceAlert> get rang => _rang.stream;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  String get _key => 'price_alerts_$_owner';

  /// Whose alerts these are: a new account on the phone sees its own.
  Future<void> load(String? owner) async {
    _owner = owner;
    _alerts = const [];
    if (owner != null) {
      try {
        final raw = (await _prefs).getString(_key);
        final list = raw == null ? const [] : jsonDecode(raw) as List;
        _alerts = [for (final j in list) ?PriceAlert.fromJson(j)];
      } catch (e) {
        debugPrint('price alerts failed to load: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    if (_owner == null) return;
    try {
      await (await _prefs).setString(
        _key,
        jsonEncode([for (final a in _alerts) a.toJson()]),
      );
    } catch (e) {
      debugPrint('price alerts failed to save: $e');
    }
  }

  /// Rings when [symbol] gets to [price] from where it is now, [current].
  /// False when there are already [max].
  Future<bool> add(String symbol, double price, double current) async {
    if (_alerts.length >= max || price == current) return false;
    _alerts = [
      ..._alerts,
      PriceAlert(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        symbol: symbol,
        price: price,
        above: price > current,
      ),
    ];
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> remove(String id) async {
    _alerts = [
      for (final a in _alerts)
        if (a.id != id) a,
    ];
    notifyListeners();
    await _save();
  }

  /// Rings every alert whose price has been reached, given each pair's
  /// price now. Called on every tick of the market.
  void check(double? Function(String symbol) priceOf) {
    final reached = [
      for (final a in _alerts)
        if (priceOf(a.symbol) case final now? when a.reachedAt(now)) a,
    ];
    if (reached.isEmpty) return;
    final gone = {for (final a in reached) a.id};
    _alerts = [
      for (final a in _alerts)
        if (!gone.contains(a.id)) a,
    ];
    notifyListeners();
    unawaited(_save());
    reached.forEach(_rang.add);
  }

  @override
  void dispose() {
    _rang.close();
    super.dispose();
  }
}

/// The phone's alerts, for every screen.
final priceAlerts = PriceAlerts();
