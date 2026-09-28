import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transaction_details.dart';
import '../../state/pos_providers.dart';
import '../../util/currency.dart';
import '../../util/pos_date_utils.dart';
import '../widgets/amount_row.dart';
import '../widgets/async_view.dart';
import '../widgets/pos_scaffold.dart';
import '../widgets/status_badge.dart';
import '../widgets/totals_panel.dart';
import 'receipt_page.dart';

final transactionDetailProvider = FutureProvider.autoDispose
    .family<TransactionDetails, int>(
      (ref, transactionId) =>
          ref.watch(posRepositoryProvider).transactionDetail(transactionId),
    );

class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({super.key, required this.transactionId});

  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(transactionDetailProvider(transactionId));
    return PosScaffold(
      title: 'Detail transaksi',
      body: AsyncView<TransactionDetails>(
        value: detail,
        onRetry: () => ref.invalidate(transactionDetailProvider(transactionId)),
        data: (transaction) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.code,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(PosDates.displayRaw(transaction.transactionDate)),
                    ],
                  ),
                ),
                StatusBadge(transaction.status),
              ],
            ),
            const Divider(height: 24),
            ...transaction.transactionItems.map(
              (line) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${line.qty}x')),
                title: Text(line.productName),
                subtitle: line.detailSummary.isEmpty
                    ? null
                    : Text(line.detailSummary),
                trailing: Text(Money.format(line.totalPrice)),
              ),
            ),
            const Divider(height: 24),
            TotalsPanel(
              rows: [
                AmountRow(label: 'Subtotal', amount: transaction.grossAmount),
                if (transaction.discountAmount != 0)
                  AmountRow(
                    label: 'Diskon',
                    amount: transaction.discountAmount,
                    negative: true,
                  ),
                if (transaction.promotionAmount != 0)
                  AmountRow(
                    label: 'Promo',
                    amount: transaction.promotionAmount,
                    negative: true,
                  ),
                if (transaction.totalServiceCharge != 0)
                  AmountRow(
                    label: 'Biaya layanan',
                    amount: transaction.totalServiceCharge,
                  ),
                if (transaction.totalTax != 0)
                  AmountRow(label: 'Pajak', amount: transaction.totalTax),
                if (transaction.totalRounding != 0)
                  AmountRow(
                    label: 'Pembulatan',
                    amount: transaction.totalRounding,
                  ),
                AmountRow(
                  label: 'TOTAL',
                  amount: transaction.totalAmount,
                  emphasis: AmountEmphasis.total,
                ),
              ],
              footer: Align(
                alignment: Alignment.centerLeft,
                child: Text('Pembayaran: ${transaction.paymentMethod}'),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceiptPage(transaction: transaction),
                ),
              ),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Lihat struk'),
            ),
          ],
        ),
      ),
    );
  }
}
