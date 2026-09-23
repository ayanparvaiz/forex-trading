import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/trade.dart';
import 'trade_repository.dart';

/// The signed-in trader's journal, in `users/{uid}/trades`.
///
/// Under the user document rather than in a top-level collection, so the
/// security rule is one line — `isOwner(uid)` — instead of a field check on
/// every document. Nobody else can read a trade, ever; sharing one copies a
/// redacted version into `/posts`.
class FirestoreTradeRepository implements TradeRepository {
  FirestoreTradeRepository({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _trades =>
      _db.collection('users').doc(uid).collection('trades');

  @override
  Future<List<Trade>> load() async {
    try {
      // Ordered by the field rather than sorted afterwards, and capped:
      // a journal is read in full on every sign-in, and an account with
      // thousands of trades should not pull all of them to draw a summary.
      final snapshot = await _trades
          .orderBy('openedAt', descending: true)
          .limit(500)
          .get();

      return [
        for (final doc in snapshot.docs.reversed)
          Trade.fromJson(doc.id, doc.data()),
      ];
    } on FirebaseException catch (error) {
      debugPrint('loading trades failed: ${error.code}');
      rethrow;
    }
  }

  @override
  Future<void> save(Trade trade) async {
    try {
      await _trades.doc(trade.id).set(trade.toJson());
    } on FirebaseException catch (error) {
      debugPrint('saving trade ${trade.id} failed: ${error.code}');
      rethrow;
    }
  }
}

/// Firestore when it is reachable, on-device storage when it is not.
///
/// Mirrors [buildCommunityRepository]: a fresh clone with no Firebase config
/// still runs the whole app, which is what keeps the project contributable
/// without an account.
TradeRepository buildTradeRepository(String uid) => FirebaseBootstrap.isReady
    ? FirestoreTradeRepository(uid: uid)
    : LocalTradeRepository(uid: uid);
