import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_bootstrap.dart';
import '../models/app_config.dart';

/// What the admins set, followed live: config/app and config/moderation,
/// readable before anyone signs in.
class AppConfigRepository {
  AppConfigRepository({FirebaseFirestore? db}) : _injected = db;

  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  Stream<AppConfig> watchApp() => _db
      .doc('config/app')
      .snapshots()
      .map((s) => AppConfig.fromJson(s.data()))
      // Offline or refused: the app as it is, never stuck behind a gate.
      .handleError((Object e) => debugPrint('app config: $e'));

  Stream<Moderation> watchModeration() => _db
      .doc('config/moderation')
      .snapshots()
      .map((s) => Moderation.fromJson(s.data()))
      .handleError((Object e) => debugPrint('moderation: $e'));
}

/// On Firestore; nothing to follow without it.
AppConfigRepository? buildAppConfig() =>
    FirebaseBootstrap.isReady ? AppConfigRepository() : null;
