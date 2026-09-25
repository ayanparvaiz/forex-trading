import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/trader.dart';

/// Someone opened from search, remembered to be found again.
class RecentPerson {
  const RecentPerson({
    required this.username,
    required this.name,
    required this.avatarId,
  });

  final String username;
  final String name;
  final int avatarId;

  Map<String, Object> toJson() => {
    'username': username,
    'name': name,
    'avatarId': avatarId,
  };

  static RecentPerson? fromJson(Object? json) {
    if (json is! Map || json['username'] is! String) return null;
    return RecentPerson(
      username: json['username'] as String,
      name: json['name'] as String? ?? '',
      avatarId: (json['avatarId'] as num?)?.toInt() ?? 1,
    );
  }
}

/// The people you last opened from search, newest first.
///
/// Kept on this phone and per account, like any app's recent searches —
/// nobody else needs them, and two people sharing a phone should not see
/// each other's.
class RecentSearches {
  RecentSearches({required String owner, SharedPreferences? prefs})
    : _key = 'search.recent.$owner',
      _injected = prefs;

  static const max = 10;

  final String _key;
  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<List<RecentPerson>> load() async {
    final raw = (await _prefs).getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          ?RecentPerson.fromJson(item),
      ];
    } catch (_) {
      // Corrupt storage costs a list of recents, nothing more.
      return const [];
    }
  }

  Future<List<RecentPerson>> _save(List<RecentPerson> people) async {
    final kept = people.take(max).toList();
    await (await _prefs).setString(
      _key,
      jsonEncode([for (final p in kept) p.toJson()]),
    );
    return kept;
  }

  /// To the front; once only.
  Future<List<RecentPerson>> add(Trader t) async => _save([
    RecentPerson(username: t.id, name: t.name, avatarId: t.avatarId),
    for (final p in await load())
      if (p.username != t.id) p,
  ]);

  Future<List<RecentPerson>> remove(String username) async => _save([
    for (final p in await load())
      if (p.username != username) p,
  ]);

  Future<void> clear() async => (await _prefs).remove(_key);
}
