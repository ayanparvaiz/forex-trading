import 'package:flutter/foundation.dart';

import '../models/instrument.dart';

/// "Trade this pair": asked from anywhere — a watchlist row — and heard by
/// the trade tab, which shows the pair, and the app's tabs, which go there.
class TradeFocus extends ChangeNotifier {
  Instrument? _pair;

  /// The pair last asked for.
  Instrument? get pair => _pair;

  void open(Instrument pair) {
    _pair = pair;
    notifyListeners();
  }
}

/// The app's one.
final tradeFocus = TradeFocus();
