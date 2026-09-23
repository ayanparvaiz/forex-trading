import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/firestore_community_repository.dart';

/// The document id for a relationship decides whether two people can end up
/// connected twice, or whether two different pairs can collide onto one row.
/// It is a pure function, so it gets tested directly rather than through
/// Firestore.
void main() {
  group('pairId', () {
    test('is the same whichever side asks', () {
      expect(
        FirestoreCommunityRepository.pairId('ayan', 'rifat'),
        FirestoreCommunityRepository.pairId('rifat', 'ayan'),
      );
    });

    test('sorts, so the id is predictable', () {
      expect(
        FirestoreCommunityRepository.pairId('rifat', 'ayan'),
        'ayan-rifat',
      );
    });

    test('cannot collide across different pairs', () {
      // Usernames may contain underscores. A separator that could appear inside
      // a name would make these two pairs share one document.
      final a = FirestoreCommunityRepository.pairId('a_', 'b');
      final b = FirestoreCommunityRepository.pairId('a', '_b');

      expect(a, isNot(b));
    });

    test('distinct pairs stay distinct across a realistic set', () {
      const names = [
        'ayan',
        'rifat',
        'nusrat',
        'a_b',
        'ab',
        'a',
        'b_',
        '_b',
        'ab_c',
        'a_bc',
      ];

      final ids = <String>{};
      final pairs = <String>{};
      for (final x in names) {
        for (final y in names) {
          if (x == y) continue;
          // Count each unordered pair once.
          final key = ([x, y]..sort()).join('|');
          if (!pairs.add(key)) continue;
          expect(
            ids.add(FirestoreCommunityRepository.pairId(x, y)),
            isTrue,
            reason: 'id collision between $x and $y',
          );
        }
      }
    });
  });
}
