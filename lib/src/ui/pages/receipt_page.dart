import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/transaction_details.dart';
import '../../state/pos_providers.dart';
import '../widgets/pos_scaffold.dart';
import '../widgets/receipt_view.dart';

class ReceiptPage extends ConsumerWidget {
  const ReceiptPage({
    super.key,
    required this.transaction,
    this.paperWidth = ReceiptPaperWidth.mm80,
  });

  final TransactionDetails transaction;
  final ReceiptPaperWidth paperWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(posConfigProvider.select((c) => c.merchant));
    final footer = ref.watch(
      paymentSettingProvider.select(
        (setting) => setting.valueOrNull?.receiptFooterText,
      ),
    );
    return PosScaffold(
      title: 'Struk transaksi',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ReceiptView(
            transaction: transaction,
            merchant: merchant,
            footerText: footer,
            paperWidth: paperWidth,
          ),
        ),
      ),
    );
  }
}
