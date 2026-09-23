/// One page of results, plus what to ask for next.
///
/// [cursor] is deliberately untyped. On the local repository it is an integer
/// offset; on Firestore it will be the last `DocumentSnapshot`. Callers only
/// ever hand it straight back, so neither side needs to know which it is.
class ResultPage<T> {
  const ResultPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
  });

  const ResultPage.empty() : items = const [], cursor = null, hasMore = false;

  final List<T> items;
  final Object? cursor;

  /// False once the end is reached, so a list stops asking.
  final bool hasMore;
}

/// Fetches one page starting from [cursor].
typedef PageFetcher<T> =
    Future<ResultPage<T>> Function({Object? cursor, int limit});
