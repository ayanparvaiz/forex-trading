import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forex_trading/data/page.dart';
import 'package:forex_trading/widgets/paged_list.dart';

/// The cap decides how much of a leaderboard anyone ever pays to read, so it
/// gets tested rather than eyeballed. An off-by-one here either cuts the list a
/// page short or defeats the cap entirely.
void main() {
  /// A source of [total] numbered rows that records what was asked for.
  ({PageFetcher<int> fetch, List<int> limits}) source(int total) {
    final limits = <int>[];

    Future<ResultPage<int>> fetch({Object? cursor, int limit = 10}) async {
      limits.add(limit);
      final start = cursor is int ? cursor : 0;
      if (start >= total || limit <= 0) return const ResultPage.empty();

      final end = (start + limit).clamp(0, total);
      return ResultPage(
        items: [for (var i = start; i < end; i++) i],
        cursor: end,
        hasMore: end < total,
      );
    }

    return (fetch: fetch, limits: limits);
  }

  Future<List<int>> drain(
    WidgetTester tester, {
    required PageFetcher<int> fetch,
    required int pageSize,
    int? maxItems,
  }) async {
    final seen = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedListView<int>(
            fetch: fetch,
            pageSize: pageSize,
            maxItems: maxItems,
            itemBuilder: (context, item, _) {
              seen.add(item);
              // Tall enough that a page overflows the test viewport —
              // a list that fits on screen never scrolls, and never pages.
              return SizedBox(height: 80, child: Text('$item'));
            },
          ),
        ),
      ),
    );

    // Pages load on scroll, so the list has to actually be scrolled — pumping
    // alone only ever gets the first page.
    for (var i = 0; i < 15; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, -400));
      }
    }
    await tester.pump(const Duration(milliseconds: 50));
    return seen;
  }

  testWidgets('stops at the cap even when more rows exist', (tester) async {
    final s = source(200);

    await drain(tester, fetch: s.fetch, pageSize: 10, maxItems: 50);

    // Never asks for more than the cap allows.
    expect(s.limits.fold<int>(0, (a, b) => a + b), lessThanOrEqualTo(50));
  });

  testWidgets('a cap that is not a multiple of the page size is exact',
      (tester) async {
    final s = source(200);

    await drain(tester, fetch: s.fetch, pageSize: 20, maxItems: 50);

    // The last page asks for the 10 that are left, not another 20.
    expect(s.limits.fold<int>(0, (a, b) => a + b), lessThanOrEqualTo(50));
    expect(s.limits.any((l) => l < 20), isTrue,
        reason: 'the final page should ask only for the remaining rows');
  });

  testWidgets('a short source finishes before the cap', (tester) async {
    final s = source(7);

    await drain(tester, fetch: s.fetch, pageSize: 5, maxItems: 50);

    // Two pages: five then two, and then it stops asking.
    expect(s.limits.length, lessThanOrEqualTo(3));
  });

  testWidgets('no cap means the source decides when to stop', (tester) async {
    final s = source(12);

    await drain(tester, fetch: s.fetch, pageSize: 5);

    expect(s.limits.every((l) => l == 5), isTrue);
  });
}
