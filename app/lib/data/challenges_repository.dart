import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/week.dart';
import '../firebase/firebase_bootstrap.dart';
import '../models/challenge.dart';

/// Weekly challenges between connections, and where each side stands.
class ChallengesRepository {
  ChallengesRepository({FirebaseFirestore? db}) : _injected = db;

  final FirebaseFirestore? _injected;

  /// Asked for when first used, so a test can stand in without Firebase.
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _all =>
      _db.collection('challenges');

  /// [uid]'s challenges of this week and last, newest week first.
  Stream<List<Challenge>> watchMine(String uid, DateTime now) {
    final weeks = {weekId(now), weekId(now.subtract(const Duration(days: 7)))};
    return _all
        .where('uids', arrayContains: uid)
        .limit(40)
        .snapshots()
        .map(
          (s) => [
            for (final d in s.docs)
              if (_from(d.id, d.data()) case final c?
                  when weeks.contains(c.week))
                c,
          ]..sort((a, b) => b.week.compareTo(a.week)),
        );
  }

  /// [uid]'s name, and their standing in [week], live.
  Stream<(String, WeekStanding)> watchSide(String uid, String week) =>
      _db.collection('users').doc(uid).snapshots().map((d) {
        final data = d.data() ?? const <String, dynamic>{};
        return (
          data['displayName'] as String? ?? '',
          WeekStanding.of(data, week),
        );
      });

  /// [from] challenges [to] — a connection, [pair] — for this week.
  Future<void> challenge({
    required String from,
    required String to,
    required String pair,
    required DateTime now,
  }) {
    final week = weekId(now);
    return _all.doc(Challenge.idFor(week, pair)).set({
      'fromUid': from,
      'toUid': to,
      'uids': [from, to],
      'pair': pair,
      'week': week,
      'createdAt': FieldValue.serverTimestamp(),
      'accepted': false,
    });
  }

  /// Whether the two have a challenge this week already.
  Future<bool> exists(String pair, DateTime now) async {
    try {
      return (await _all.doc(Challenge.idFor(weekId(now), pair)).get()).exists;
    } catch (_) {
      // Not theirs to read: someone else's.
      return false;
    }
  }

  Future<void> accept(String id) => _all.doc(id).update({'accepted': true});

  /// Declined, or called off.
  Future<void> remove(String id) => _all.doc(id).delete();

  static Challenge? _from(String id, Map<String, dynamic> d) {
    final from = d['fromUid'], to = d['toUid'], week = d['week'];
    if (from is! String || to is! String || week is! String) return null;
    return Challenge(
      id: id,
      fromUid: from,
      toUid: to,
      pair: d['pair'] as String? ?? '',
      week: week,
      accepted: d['accepted'] == true,
    );
  }
}

/// Firestore when it is configured; nothing otherwise.
ChallengesRepository? buildChallenges() =>
    FirebaseBootstrap.isReady ? ChallengesRepository() : null;
