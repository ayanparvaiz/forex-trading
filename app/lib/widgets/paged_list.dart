import 'package:flutter/material.dart';

import '../data/page.dart';
import '../data/session_controller.dart';
import '../theme/app_theme.dart';

/// A list that loads one page at a time as it is scrolled.
///
/// Nothing in this app ever fetches a whole collection. A leaderboard with ten
/// thousand traders on it would hang a budget phone for seconds and burn the
/// Firestore read quota in one pull, so every list here is paged — including
/// the ones that are short today.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.header,
    this.emptyLabel,
    this.pageSize = 12,
    this.maxItems,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.separator = Gap.h8,
  });

  final PageFetcher<T> fetch;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Pinned above the first item and kept while more pages load.
  final Widget? header;

  final String? emptyLabel;
  final int pageSize;

  /// Hard stop on how many rows the list will ever show.
  ///
  /// Not a page size — a ceiling. Past it the list stops asking for more, so a
  /// capped leaderboard costs the same whether there are sixty accounts or
  /// sixty thousand.
  final int? maxItems;
  final EdgeInsets padding;
  final Widget separator;

  @override
  State<PagedListView<T>> createState() => PagedListViewState<T>();
}

class PagedListViewState<T> extends State<PagedListView<T>> {
  final _controller = ScrollController();
  final _items = <T>[];

  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _firstLoadDone = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    // Start the next page before the bottom is reached, so scrolling stays
    // smooth instead of stuttering at the end of every page.
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cap = widget.maxItems;
      // Ask for only what is left under the cap, so the last page does not
      // fetch rows that are about to be thrown away.
      final room = cap == null ? widget.pageSize : cap - _items.length;

      final page = await widget.fetch(
        cursor: _cursor,
        limit: room < widget.pageSize ? room : widget.pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        // addAll already counted the new rows; adding them again here would
        // stop the list a page early.
        _hasMore = page.hasMore && (cap == null || _items.length < cap);
        _loading = false;
        _firstLoadDone = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
        _firstLoadDone = true;
      });
    }
  }

  /// Throws the loaded pages away and starts again from the top.
  Future<void> refresh() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _loading = false;
      _firstLoadDone = false;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (!_firstLoadDone) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Gap.xxl),
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.brand,
          ),
        ),
      );
    }

    if (_items.isEmpty && widget.emptyLabel != null) {
      return RefreshIndicator(
        onRefresh: refresh,
        color: AppColors.brand,
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: widget.padding,
          children: [
            if (widget.header != null) widget.header!,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xxl),
              child: Text(
                widget.emptyLabel!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // One extra row for the header, and one for the footer spinner.
    final headerCount = widget.header != null ? 1 : 0;
    final footerCount = _hasMore || _error != null ? 1 : 0;

    return RefreshIndicator(
      onRefresh: refresh,
      color: AppColors.brand,
      backgroundColor: AppColors.surface,
      child: ListView.builder(
        controller: _controller,
        padding: widget.padding,
        itemCount: headerCount + _items.length + footerCount,
        itemBuilder: (context, index) {
          if (widget.header != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Gap.lg),
              child: widget.header,
            );
          }

          final itemIndex = index - headerCount;
          if (itemIndex < _items.length) {
            return Padding(
              padding: EdgeInsets.only(bottom: Gap.sm),
              child: widget.itemBuilder(context, _items[itemIndex], itemIndex),
            );
          }

          return _Footer(
            error: _error,
            onRetry: () {
              setState(() => _error = null);
              _loadMore();
            },
          );
        },
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 17),
            label: Text(context.s.retry),
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          ),
        ),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
