import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'score_sync.dart';

/// The day's reference rates the practice market starts from.
///
/// The European Central Bank's, one per working day, served by the worker
/// (worker/src/rates.js). Not live prices: the market moves on its own from
/// here, and the trade screen says so.
class ReferenceRates {
  const ReferenceRates({required this.pairs, required this.date});

  /// Price per pair, e.g. `EUR/USD` → 1.1403.
  final Map<String, double> pairs;

  /// The ECB's date for them, `2026-09-25`.
  final String date;

  /// Anything outside these is a broken feed, not a market.
  static const _bounds = {
    'EUR/USD': (0.5, 2.5),
    'GBP/USD': (0.5, 3.0),
    'USD/JPY': (50.0, 400.0),
  };

  static ReferenceRates? fromJson(Object? json) {
    if (json is! Map || json['pairs'] is! Map || json['date'] is! String) {
      return null;
    }
    final pairs = <String, double>{};
    for (final MapEntry(:key, :value) in (json['pairs'] as Map).entries) {
      final bounds = _bounds[key];
      if (bounds == null || value is! num) continue;
      final v = value.toDouble();
      if (v >= bounds.$1 && v <= bounds.$2) pairs[key as String] = v;
    }
    return pairs.isEmpty
        ? null
        : ReferenceRates(pairs: pairs, date: json['date'] as String);
  }

  Map<String, Object> toJson() => {'pairs': pairs, 'date': date};
}

/// Fetches the rates, and keeps the last ones on the phone so the market
/// starts in the right place even offline.
class ReferenceRatesSource {
  ReferenceRatesSource({Uri? endpoint, HttpClient? client})
    : endpoint = endpoint ?? ratesEndpoint,
      _client = client ?? HttpClient();

  final Uri endpoint;
  final HttpClient _client;

  static const _key = 'market.referenceRates';

  /// The rates from the last successful fetch, if any.
  Future<ReferenceRates?> cached() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      return raw == null ? null : ReferenceRates.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Today's rates, remembered for next time. Null when the worker cannot be
  /// reached — the market keeps what it had.
  Future<ReferenceRates?> fetch({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final request = await _client.getUrl(endpoint).timeout(timeout);
      // See WorkerScoreSync: Cloudflare refuses some stock client strings.
      request.headers.set(HttpHeaders.userAgentHeader, 'forex-trading-app');
      final response = await request.close().timeout(timeout);
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) return null;
      final rates = ReferenceRates.fromJson(jsonDecode(text));
      if (rates != null) {
        await (await SharedPreferences.getInstance()).setString(
          _key,
          jsonEncode(rates.toJson()),
        );
      }
      return rates;
    } catch (e) {
      debugPrint('reference rates failed: $e');
      return null;
    }
  }

  void close() => _client.close();
}

/// The same worker as [statsEndpoint].
final Uri ratesEndpoint = statsEndpoint.resolve('/rates');
