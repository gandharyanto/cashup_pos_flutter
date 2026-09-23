import 'package:flutter/material.dart';

import '../../models/transaction_details.dart';
import '../widgets/pos_scaffold.dart';

class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({super.key, required this.transaction});
  final CreatedTransaction transaction;

  @override
  Widget build(BuildContext context) => PosScaffold(
    title: 'Pembayaran berhasil',
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 72),
          const Text('Transaksi berhasil'),
          Text(transaction.trxId),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
    ),
  );
}
