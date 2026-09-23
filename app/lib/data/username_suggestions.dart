import 'dart:math';

import 'auth_repository.dart';

/// Builds free usernames near [base].
///
/// Shared by both repositories: the suggestions a person sees must not change
/// depending on whether the app is running on local storage or Firestore, and
/// the only thing that actually differs between them is how availability is
/// checked — which is why that is the parameter.
Future<List<String>> suggestFreeUsernames(
  String base, {
  required Future<bool> Function(String) isFree,
  int count = 4,
}) async {
  // Strip anything the username rules would reject, so a suggestion built from
  // "Rifat Hasan!" starts from "rifathasan".
  var stem = AuthRepository.normalise(base).replaceAll(RegExp(r'[^a-z0-9_]'), '');
  if (stem.length < 3) stem = stem.isEmpty ? 'trader' : '${stem}fx';
  if (stem.length > 14) stem = stem.substring(0, 14);

  final random = Random();
  final candidates = <String>{
    '${stem}fx',
    '${stem}_fx',
    '$stem${random.nextInt(90) + 10}',
    '${stem}trades',
    '${stem}_${random.nextInt(900) + 100}',
    'the$stem',
    '${stem}pips',
    '$stem${DateTime.now().year % 100}',
  };

  final free = <String>[];
  for (final candidate in candidates) {
    if (free.length >= count) break;
    if (candidate.length > 20) continue;
    if (await isFree(candidate)) free.add(candidate);
  }
  return free;
}
