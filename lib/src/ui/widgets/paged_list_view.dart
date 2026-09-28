/// Infinite-scroll list with a loading / error footer. Backs transactions,
/// stock movement and product management.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A default scroll-extent threshold used when the caller supplies no
/// [PagedListView.itemExtent] to derive one from.
const double _defaultLoadMoreThreshold = 200;

/// A virtualised, paginated list.
///
/// [onLoadMore] is triggered by a [ScrollController] listener once the
/// viewport nears [ScrollPosition.maxScrollExtent] — never by building a
/// sentinel/loader item that re-runs load-more logic in [itemBuilder] on
/// every frame.
class PagedListView<T> extends StatefulWidget {
  /// Creates a paged list.
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

  /// The currently loaded items.
  final List<T> items;

  /// Builds the row for one item.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Whether another page can be requested.
  final bool hasMore;

  /// Called once when the scroll position crosses the load-more threshold.
  final VoidCallback onLoadMore;

  /// Shows a footer spinner instead of nothing while a page is in flight.
  final bool isLoadingMore;

  /// When set, shows an error footer with a "Coba Lagi" retry button
  /// instead of the loading footer.
  final String? error;

  /// Called when the retry button in the error footer is tapped.
  final VoidCallback? onRetry;

  /// Fixed row height for a scroll-offset-cheap, `SliverFixedExtentList`-
  /// backed list; also used to size the load-more threshold. Ignored for
  /// sliver layout (falls back to natural sizing) when [separator] is also
  /// set — a separator's height is arbitrary and can't be safely baked into
  /// a single fixed slot alongside the row without measuring it.
  final double? itemExtent;

  /// Optional separator rendered between rows (not after the last one).
  final Widget? separator;

  /// List padding.
  final EdgeInsetsGeometry? padding;

  /// Enables pull-to-refresh when set.
  final Future<void> Function()? onRefresh;

  /// Shown instead of the list when [items] is empty and there is no
  /// [error].
  final Widget? emptyPlaceholder;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  late final ScrollController _controller;

  // Guards against firing `onLoadMore` on every scroll tick once the
  // threshold has been crossed — reset when new items arrive or a page
  // finishes loading, so exactly one request goes out per threshold
  // crossing.
  bool _loadMoreTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant PagedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final itemsChanged = widget.items.length != oldWidget.items.length;
    final loadingFinished = oldWidget.isLoadingMore && !widget.isLoadingMore;
    if (itemsChanged || loadingFinished) {
      _loadMoreTriggered = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.hasMore || widget.isLoadingMore || _loadMoreTriggered) return;
    if (!_controller.hasClients) return;

    final position = _controller.position;
    final threshold = widget.itemExtent != null
        ? widget.itemExtent! * 3
        : _defaultLoadMoreThreshold;
    if (position.pixels >= position.maxScrollExtent - threshold) {
      _loadMoreTriggered = true;
      widget.onLoadMore();
    }
  }

  bool get _hasFooter => widget.error != null || widget.isLoadingMore;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && widget.error == null) {
      return widget.emptyPlaceholder ?? const SizedBox.shrink();
    }

    final hasFooter = _hasFooter;
    final hasSeparator = widget.separator != null;
    // See the [PagedListView.itemExtent] doc: not honoured for sliver
    // layout once a separator is in play.
    final fixedExtent = hasSeparator ? null : widget.itemExtent;

    Widget list;
    if (fixedExtent != null && !hasFooter) {
      // Fast path: identical to a plain `ListView.builder` — every child is
      // a uniform-height row with nothing else sharing its slot, so a
      // single `SliverFixedExtentList` is safe.
      list = ListView.builder(
        controller: _controller,
        padding: widget.padding,
        itemExtent: fixedExtent,
        itemCount: widget.items.length,
        itemBuilder: (context, index) =>
            widget.itemBuilder(context, widget.items[index], index),
      );
    } else {
      // General path. The footer (natural height: text, a spinner, a retry
      // button) is a separate sliver appended after the items — never
      // forced into an item's fixed slot, regardless of whether the items
      // themselves use a fixed extent.
      list = CustomScrollView(
        controller: _controller,
        slivers: [
          SliverPadding(
            padding: widget.padding ?? EdgeInsets.zero,
            sliver: SliverMainAxisGroup(
              slivers: [
                _itemsSliver(fixedExtent, hasSeparator),
                if (hasFooter)
                  SliverToBoxAdapter(
                    child: _Footer(
                      error: widget.error,
                      onRetry: widget.onRetry,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    final onRefresh = widget.onRefresh;
    if (onRefresh != null) {
      list = RefreshIndicator(onRefresh: onRefresh, child: list);
    }
    return list;
  }

  Widget _itemsSliver(double? fixedExtent, bool hasSeparator) {
    Widget buildRow(BuildContext context, int index) {
      final row = widget.itemBuilder(context, widget.items[index], index);
      if (!hasSeparator || index == widget.items.length - 1) return row;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [row, widget.separator!],
      );
    }

    if (fixedExtent != null) {
      return SliverFixedExtentList(
        itemExtent: fixedExtent,
        delegate: SliverChildBuilderDelegate(
          buildRow,
          childCount: widget.items.length,
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        buildRow,
        childCount: widget.items.length,
      ),
    );
  }
}

/// The list's trailing row: a retry prompt when [error] is set, otherwise a
/// loading spinner.
class _Footer extends StatelessWidget {
  const _Footer({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = error;
    if (message != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: _spacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: _spacing.s),
              TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _spacing.m),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
