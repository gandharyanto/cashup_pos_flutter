import 'package:flutter/material.dart';

import 'empty_state.dart';
import 'error_state.dart';

/// Infinite-scroll list with a loading / error footer. Backs transactions,
/// stock movement and product management.
///
/// This is a [StatefulWidget] because it owns a [ScrollController] — nothing
/// else. [items], [hasMore] and [isLoadingMore] all stay with the caller;
/// this widget never mutates or caches them, so a rebuild with a new
/// [items] list (a fresh page appended, or a pull-to-refresh reset) is
/// simply rendered as-is.
///
/// [onLoadMore] fires from a [ScrollController] listener that compares
/// [ScrollPosition.pixels] against [ScrollPosition.maxScrollExtent] minus a
/// fixed threshold — not from a sentinel list item that re-checks on every
/// build. A sentinel-item check re-runs on every frame the list repaints
/// (each scroll tick rebuilds `itemBuilder` for the visible range); a
/// listener only runs when the scroll position actually changes, and does
/// not itself cause a rebuild.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.hasMore,
    required this.onLoadMore,
    this.isLoadingMore = false,
    this.error,
    this.onRetry,
    this.itemExtent,
    this.separator,
    this.padding,
    this.onRefresh,
    this.emptyPlaceholder,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Whether a further page exists beyond [items] — controls both whether
  /// scrolling near the end triggers [onLoadMore] and whether the loading
  /// footer is eligible to show.
  final bool hasMore;

  /// Requests the next page. The caller is expected to flip
  /// [isLoadingMore] (or [hasMore]) in response so this is not re-triggered
  /// on every subsequent scroll tick while the request is in flight.
  final VoidCallback onLoadMore;
  final bool isLoadingMore;

  /// A page-load failure message. Showing it takes priority over the
  /// loading footer and suppresses further automatic [onLoadMore] calls
  /// until [onRetry] is used.
  final String? error;
  final VoidCallback? onRetry;

  /// Fixed row height. When given (and [separator] is not), the list is
  /// built with `ListView.builder(itemExtent: ...)` — see the class doc
  /// comment on why a uniform extent matters for scroll performance.
  final double? itemExtent;
  final Widget? separator;
  final EdgeInsetsGeometry? padding;
  final Future<void> Function()? onRefresh;
  final Widget? emptyPlaceholder;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final ScrollController _controller = ScrollController();

  /// How close to the end (in logical pixels) the viewport must scroll
  /// before [PagedListView.onLoadMore] fires.
  static const double _loadMoreThreshold = 240;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.hasMore || widget.isLoadingMore || widget.error != null) {
      return;
    }
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining <= _loadMoreThreshold) {
      widget.onLoadMore();
    }
  }

  bool get _hasFooter => widget.isLoadingMore || widget.error != null;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && widget.error == null) {
      return widget.emptyPlaceholder ??
          const EmptyState(title: 'Tidak ada data');
    }

    final itemCount = widget.items.length + (_hasFooter ? 1 : 0);
    final useFixedExtent =
        widget.itemExtent != null && widget.separator == null;

    final list = useFixedExtent
        ? ListView.builder(
            controller: _controller,
            padding: widget.padding,
            itemExtent: widget.itemExtent,
            itemCount: itemCount,
            itemBuilder: (context, index) => _buildItem(context, index),
          )
        : ListView.separated(
            controller: _controller,
            padding: widget.padding,
            itemCount: itemCount,
            separatorBuilder: (context, index) =>
                widget.separator ?? const SizedBox.shrink(),
            itemBuilder: (context, index) => _buildItem(context, index),
          );

    final onRefresh = widget.onRefresh;
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh, child: list);
  }

  Widget _buildItem(BuildContext context, int index) {
    if (index < widget.items.length) {
      return widget.itemBuilder(context, widget.items[index], index);
    }
    final error = widget.error;
    if (error != null) {
      return ErrorState(message: error, onRetry: widget.onRetry);
    }
    return const _LoadingFooter();
  }
}

class _LoadingFooter extends StatelessWidget {
  const _LoadingFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
