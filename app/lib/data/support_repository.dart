import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/support_message.dart';

/// Writing to the admins, and reading their answers.
abstract class SupportSource {
  /// What [uid] has written, newest first, answers and all, live.
  Stream<List<SupportMessage>> watchMine(String uid);

  Future<void> send({
    required String uid,
    required String username,
    required String text,
  });
}

class FirestoreSupport implements SupportSource {
  FirestoreSupport({FirebaseFirestore? db}) : _injected = db;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _all =>
      _db.collection('support');

  @override
  Stream<List<SupportMessage>> watchMine(String uid) => _all
      // The rules let each person read their own only, so the query says so.
      .where('uid', isEqualTo: uid)
      .limit(50)
      .snapshots()
      .map((s) {
        final out = [
          for (final d in s.docs) SupportMessage.fromJson(d.id, d.data()),
        ];
        // Sorted here: an orderBy would need an index for this alone.
        out.sort(
          (a, b) => (b.sentAt ?? DateTime(9999)).compareTo(
            a.sentAt ?? DateTime(9999),
          ),
        );
        return out;
      });

  @override
  Future<void> send({
    required String uid,
    required String username,
    required String text,
  }) => _all.add({
    'uid': uid,
    'username': username,
    'text': text.trim(),
    'createdAt': FieldValue.serverTimestamp(),
    'status': 'open',
  });
}

/// On Firestore; nobody to write to without it.
SupportSource? buildSupport() =>
    FirebaseBootstrap.isReady ? FirestoreSupport() : null;
