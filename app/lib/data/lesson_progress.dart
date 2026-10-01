import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firebase_bootstrap.dart';

/// Which lessons someone has passed — on their profile, where the worker
/// reads them to award "scholar" (worker/src/achievements.js).
abstract class LessonProgress {
  Stream<Set<String>> watch(String uid);
  Future<void> pass(String uid, String lessonId);
}

class FirestoreLessonProgress implements LessonProgress {
  FirestoreLessonProgress({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<Set<String>> watch(String uid) => _user(uid).snapshots().map(
    (d) => {
      for (final id in d.data()?['lessonsDone'] as List<dynamic>? ?? const [])
        if (id is String) id,
    },
  );

  @override
  Future<void> pass(String uid, String lessonId) => _user(uid).update({
    'lessonsDone': FieldValue.arrayUnion([lessonId]),
  });
}

/// For a phone with no server: kept while the app is open.
class MemoryLessonProgress implements LessonProgress {
  final _done = <String>{};

  @override
  Stream<Set<String>> watch(String uid) async* {
    yield {..._done};
  }

  @override
  Future<void> pass(String uid, String lessonId) async => _done.add(lessonId);
}

LessonProgress? _built;

LessonProgress get lessonProgress => _built ??= FirebaseBootstrap.isReady
    ? FirestoreLessonProgress()
    : MemoryLessonProgress();
