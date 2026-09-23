import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_summary.dart';
import 'pos_providers.dart';

class TransactionHistoryState {
  const TransactionHistoryState({
    required this.startDate,
    required this.endDate,
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<TransactionSummaryRow> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;

  TransactionHistoryState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    List<TransactionSummaryRow>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearError = false,
  }) => TransactionHistoryState(
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearError ? null : loadMoreError ?? this.loadMoreError,
  );
}

final transactionHistoryControllerProvider =
    AsyncNotifierProvider<
      TransactionHistoryController,
      TransactionHistoryState
    >(TransactionHistoryController.new);

class TransactionHistoryController
    extends AsyncNotifier<TransactionHistoryState> {
  static const pageSize = 20;

  @override
  Future<TransactionHistoryState> build() async {
    final now = DateTime.now();
    return _fetch(DateTime(now.year, now.month, 1), now);
  }

  Future<void> setRange(DateTime startDate, DateTime endDate) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(startDate, endDate));
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = await AsyncValue.guard(
      () => _fetch(current.startDate, current.endDate),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true, clearError: true));
    try {
      final result = await ref
          .read(posRepositoryProvider)
          .transactionList(
            page: current.page + 1,
            size: pageSize,
            startDate: current.startDate,
            endDate: current.endDate,
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...result.items],
          page: result.page,
          hasMore: result.hasMore,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: error.toString()),
      );
    }
  }

  Future<TransactionHistoryState> _fetch(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = await ref
        .read(posRepositoryProvider)
        .transactionList(
          page: 0,
          size: pageSize,
          startDate: startDate,
          endDate: endDate,
        );
    return TransactionHistoryState(
      startDate: startDate,
      endDate: endDate,
      items: result.items,
      page: result.page,
      hasMore: result.hasMore,
    );
  }
}
