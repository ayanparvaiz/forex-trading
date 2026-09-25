import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trade.dart';

/// Where a trader's own trades are kept.
///
/// Private to the account, unlike everything in [CommunityRepository]. Sharing
/// a trade copies a redacted version into the feed rather than opening the
/// journal, so this never needs to be readable by anyone else.
abstract class TradeRepository {
  /// Every trade this account has ever placed, oldest first.
  Future<List<Trade>> load();

  /// Writes one trade, creating it or replacing it.
  ///
  /// One method rather than create/update, because the store already holds the
  /// whole trade and the id never changes — a write is always "this is what
  /// the trade is now".
  Future<void> save(Trade trade);
}

/// Keeps nothing. Used when nobody is signed in.
///
/// A real object rather than a null check at every call site: the store should
/// not have to know whether there is anywhere to write.
class NoTradeRepository implements TradeRepository {
  const NoTradeRepository();

  @override
  Future<List<Trade>> load() async => const [];

  @override
  Future<void> save(Trade trade) async {}
}

/// On-device storage, for a clone with no Firebase configured.
///
/// Keyed by account id so two people on one phone do not read each other's
/// journals — the same shape the Firestore version has, one collection per
/// account.
class LocalTradeRepository implements TradeRepository {
  LocalTradeRepository({required this.uid, SharedPreferences? prefs})
    : _injected = prefs;

  final String uid;
  final SharedPreferences? _injected;
  SharedPreferences? _cached;

  /// Where [uid]'s journal is kept. Deleting a local account clears it.
  static String keyFor(String uid) => 'trades.$uid';

  String get _key => keyFor(uid);

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  @override
  Future<List<Trade>> load() async {
    final raw = (await _prefs).getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final trades = [
        for (final entry in decoded.entries)
          Trade.fromJson(
            entry.key,
            (entry.value as Map).cast<String, Object?>(),
          ),
      ]..sort((a, b) => a.openedAt.compareTo(b.openedAt));
      return trades;
    } catch (error) {
      // A journal that cannot be parsed is not worth crashing the app over,
      // but it is worth saying out loud rather than silently starting empty.
      debugPrint('stored trades could not be read: $error');
      return const [];
    }
  }

  @override
  Future<void> save(Trade trade) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_key);

    final all = <String, Object?>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        all.addAll(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Overwritten below rather than lost silently — see load().
      }
    }

    all[trade.id] = trade.toJson();
    await prefs.setString(_key, jsonEncode(all));
  }
}
