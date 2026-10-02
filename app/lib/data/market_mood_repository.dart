import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/market_mood.dart';

/// Where the market's mood is kept and voted on. See [MarketMood].
abstract class MarketMoodSource {
  /// Today's mood on [pair] in [scope] — everyone's, or a community's —
  /// live.
  Stream<MarketMood> watch(String scope, String pair, String day);

  /// My side on [pair] today, or none.
  Future<void> vote({
    required String scope,
    required String pair,
    required String day,
    required String me,
    required MoodSide? side,
  });
}

/// One document a day per pair and scope: `{scope}_{pair}_{day}`, holding
/// who said up and who said down.
class FirestoreMarketMood implements MarketMoodSource {
  FirestoreMarketMood({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(
    String scope,
    String pair,
    String day,
  ) => _db.collection('sentiment').doc('${scope}_${pair}_$day');

  @override
  Stream<MarketMood> watch(String scope, String pair, String day) =>
      _doc(scope, pair, day).snapshots().map((d) {
        final data = d.data();
        if (data == null) return MarketMood.none;
        Set<String> uids(Object? l) => {
          if (l is List)
            for (final u in l)
              if (u is String) u,
        };
        return MarketMood(
          bulls: uids(data['bulls']),
          bears: uids(data['bears']),
        );
      });

  @override
  Future<void> vote({
    required String scope,
    required String pair,
    required String day,
    required String me,
    required MoodSide? side,
  }) {
    final ref = _doc(scope, pair, day);
    // The first vote of the day makes the document; every other moves only
    // my own uid, so two people voting at once never undo each other.
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        if (side == null) return;
        tx.set(ref, {
          'scope': scope,
          'pair': pair,
          'day': day,
          'bulls': [if (side == MoodSide.up) me],
          'bears': [if (side == MoodSide.down) me],
        });
        return;
      }
      tx.update(ref, {
        'bulls': side == MoodSide.up
            ? FieldValue.arrayUnion([me])
            : FieldValue.arrayRemove([me]),
        'bears': side == MoodSide.down
            ? FieldValue.arrayUnion([me])
            : FieldValue.arrayRemove([me]),
      });
    });
  }
}

/// Firestore when it is configured; nothing otherwise — a mood needs other
/// people.
MarketMoodSource? buildMarketMood() =>
    FirebaseBootstrap.isReady ? FirestoreMarketMood() : null;
