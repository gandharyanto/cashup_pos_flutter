import 'package:cashup_pos/src/data/pos_repository.dart';
import 'package:cashup_pos/src/models/paged_result.dart';
import 'package:cashup_pos/src/models/transaction_summary.dart';
import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:cashup_pos/src/state/transaction_history_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_repository.dart';

class PagingRepository extends FakeRepository {
  final requestedPages = <int>[];
  final requestedSizes = <int>[];
  final ranges = <(DateTime, DateTime)>[];

  @override
  Future<PagedResult<TransactionSummaryRow>> transactionList({
    required int page,
    required int size,
    required DateTime startDate,
    required DateTime endDate,
    String sortBy = 'transactionDate',
    String sortType = 'DESC',
  }) async {
    requestedPages.add(page);
    requestedSizes.add(size);
    ranges.add((startDate, endDate));
    return PagedResult(
      items: [TransactionSummaryRow(id: page + 1, code: 'T$page')],
      page: page,
      size: size,
      totalElements: 2,
      totalPages: 2,
    );
  }
}

ProviderContainer containerFor(PosRepository repository) => ProviderContainer(
  overrides: [posRepositoryProvider.overrideWithValue(repository)],
);

void main() {
  test('loads transactions 20 at a time and appends the next page', () async {
    final repository = PagingRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);

    final first = await container.read(
      transactionHistoryControllerProvider.future,
    );
    expect(first.items.single.code, 'T0');
    expect(first.hasMore, isTrue);

    await container
        .read(transactionHistoryControllerProvider.notifier)
        .loadMore();
    final second = container
        .read(transactionHistoryControllerProvider)
        .requireValue;
    expect(second.items.map((row) => row.code), ['T0', 'T1']);
    expect(second.hasMore, isFalse);
    expect(repository.requestedPages, [0, 1]);
    expect(repository.requestedSizes, [20, 20]);
  });

  test('changing date range resets pagination to page zero', () async {
    final repository = PagingRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    await container.read(transactionHistoryControllerProvider.future);
    final start = DateTime(2026, 8, 1);
    final end = DateTime(2026, 8, 31);

    await container
        .read(transactionHistoryControllerProvider.notifier)
        .setRange(start, end);

    final state = container
        .read(transactionHistoryControllerProvider)
        .requireValue;
    expect(state.startDate, start);
    expect(state.endDate, end);
    expect(repository.requestedPages.last, 0);
    expect(repository.ranges.last, (start, end));
  });
}
