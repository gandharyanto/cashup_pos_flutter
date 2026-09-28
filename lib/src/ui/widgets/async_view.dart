import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';
import 'error_state.dart';
import 'loading_state.dart';

/// The single loading/error/empty/data switch used by every page that reads
/// an `AsyncNotifier` (cart, catalogue, checkout, transactions, ...).
///
/// [AsyncValue] is a plain value type, not a `WidgetRef` — pages pass the
/// value they already `ref.watch`ed, so this widget stays reusable without
/// reaching into Riverpod itself.
///
/// This is a [StatelessWidget]: every branch is derived straight from
/// [value] inside [build] via [AsyncValue.when], with no internal state of
/// its own. That matters for a background refresh (`ref.refresh` /
/// pull-to-refresh on an already-loaded page): `AsyncValue.when`'s default
/// `skipLoadingOnRefresh: true` routes a refreshing-with-previous-data state
/// through the `data` branch (using the previous value) instead of the
/// `loading` branch, so [data] keeps being rebuilt in place rather than
/// being torn down and replaced by [LoadingState] and back — there is no
/// separate "loading flag" tracked anywhere that could cause an extra
/// unmount/remount of the data subtree. Only a load with no previous value
/// at all (the four tests below) reaches the `loading` branch.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loading,
  });

  /// The watched async state.
  final AsyncValue<T> value;

  /// Builds the data subtree once [value] holds data that is not empty.
  final Widget Function(T data) data;

  /// Passed to [ErrorState.fromException] as the retry callback.
  final VoidCallback? onRetry;

  /// Reports whether the loaded [T] should be treated as "nothing to show"
  /// (e.g. an empty list). Omit to never show [empty].
  final bool Function(T data)? isEmpty;

  /// Shown when [isEmpty] reports `true`. Defaults to a generic
  /// [EmptyState].
  final Widget? empty;

  /// Shown while [value] is loading with no previous data. Defaults to a
  /// plain [LoadingState].
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (loaded) {
        final showEmpty = isEmpty?.call(loaded) ?? false;
        return showEmpty
            ? (empty ?? const EmptyState(title: 'Tidak ada data'))
            : data(loaded);
      },
      error: (error, stackTrace) =>
          ErrorState.fromException(error, onRetry: onRetry),
      loading: () => loading ?? const LoadingState(),
    );
  }
}
