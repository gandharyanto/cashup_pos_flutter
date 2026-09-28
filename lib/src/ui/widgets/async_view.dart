/// The single loading/error/empty/data switch used by every page that reads
/// an [AsyncValue] from a Riverpod controller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';
import 'error_state.dart';
import 'loading_state.dart';

/// Renders [value] as loading, error, empty or data, in that priority order.
///
/// Deliberately does not use [AsyncValue.when], which switches purely on the
/// current variant (loading/error/data) and would tear down the [data]
/// subtree the instant a refresh sets `isLoading: true` — even when a
/// previous value is still attached. Checking [AsyncValue.hasValue] first
/// instead means a background refresh keeps rendering stale data rather
/// than flashing back to [LoadingState].
class AsyncView<T> extends StatelessWidget {
  /// Creates an async view over [value].
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loading,
  });

  /// The async value to render.
  final AsyncValue<T> value;

  /// Builds the data subtree once [value] carries a non-empty value.
  final Widget Function(T data) data;

  /// Passed to [ErrorState.fromException] as the retry action.
  final VoidCallback? onRetry;

  /// Reports whether a present value should be treated as empty. When null,
  /// a present value is never considered empty.
  final bool Function(T data)? isEmpty;

  /// Shown instead of [data] when [isEmpty] reports true. Defaults to a
  /// generic [EmptyState].
  final Widget? empty;

  /// Shown while [value] has neither a value nor an error. Defaults to a
  /// generic [LoadingState].
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final data = value.value as T;
      if (isEmpty != null && isEmpty!(data)) {
        return empty ?? const EmptyState(title: 'Tidak ada data');
      }
      return this.data(data);
    }
    if (value.hasError) {
      return ErrorState.fromException(value.error!, onRetry: onRetry);
    }
    return loading ?? const LoadingState();
  }
}
