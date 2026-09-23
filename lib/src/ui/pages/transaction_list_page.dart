import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transaction_summary.dart';
import '../../state/transaction_history_controller.dart';
import '../../util/currency.dart';
import '../../util/pos_date_utils.dart';
import '../widgets/async_view.dart';
import '../widgets/date_range_field.dart';
import '../widgets/paged_list_view.dart';
import '../widgets/pos_scaffold.dart';
import '../widgets/status_badge.dart';
import 'transaction_detail_page.dart';

class TransactionListPage extends ConsumerWidget {
  const TransactionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(transactionHistoryControllerProvider);
    final controller = ref.read(transactionHistoryControllerProvider.notifier);
    return PosScaffold(
      title: 'Riwayat transaksi',
      body: AsyncView<TransactionHistoryState>(
        value: history,
        onRetry: controller.refresh,
        data: (value) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DateRangeField(
                start: value.startDate,
                end: value.endDate,
                onChanged: controller.setRange,
              ),
            ),
            Expanded(
              child: PagedListView<TransactionSummaryRow>(
                items: value.items,
                hasMore: value.hasMore,
                isLoadingMore: value.isLoadingMore,
                error: value.loadMoreError,
                onLoadMore: controller.loadMore,
                onRetry: controller.loadMore,
                onRefresh: controller.refresh,
                separator: const Divider(height: 1),
                itemBuilder: (context, row, index) => ListTile(
                  title: Text(row.code ?? row.trxId ?? '-'),
                  subtitle: Text(
                    '${PosDates.displayRaw(row.transactionDate)} · ${row.paymentMethod ?? '-'}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Money.format(row.totalAmountValue)),
                      const SizedBox(height: 4),
                      StatusBadge(row.status ?? '-'),
                    ],
                  ),
                  onTap: row.id == null
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TransactionDetailPage(transactionId: row.id!),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
