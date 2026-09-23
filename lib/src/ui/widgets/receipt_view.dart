import 'package:flutter/material.dart';

import '../../config/pos_config.dart';
import '../../models/transaction_details.dart';
import '../../util/currency.dart';
import '../../util/pos_date_utils.dart';
import 'amount_row.dart';

enum ReceiptPaperWidth { mm58, mm80 }

extension ReceiptPaperWidthX on ReceiptPaperWidth {
  double get logicalWidth => this == ReceiptPaperWidth.mm58 ? 219 : 302;
}

/// Printable receipt body shared by payment result and transaction detail.
class ReceiptView extends StatelessWidget {
  const ReceiptView({
    super.key,
    required this.transaction,
    required this.merchant,
    this.footerText,
    this.paperWidth = ReceiptPaperWidth.mm80,
  });

  final TransactionDetails transaction;
  final PosMerchant merchant;
  final String? footerText;
  final ReceiptPaperWidth paperWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: paperWidth.logicalWidth,
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context),
          const _ReceiptRule(),
          Text(
            transaction.code,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            PosDates.displayRaw(transaction.transactionDate),
            textAlign: TextAlign.center,
          ),
          const _ReceiptRule(),
          ...transaction.transactionItems.map(_line),
          if (_hasText(transaction.notes)) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Catatan: ${transaction.notes!.trim()}'),
            ),
          ],
          const _ReceiptRule(),
          if (transaction.discountAmount != 0)
            AmountRow(
              label: transaction.discountName?.trim().isNotEmpty == true
                  ? 'Diskon (${transaction.discountName!.trim()})'
                  : 'Diskon',
              amount: transaction.discountAmount,
              negative: true,
            ),
          if (transaction.promotionAmount != 0)
            AmountRow(
              label: 'Promo',
              amount: transaction.promotionAmount,
              negative: true,
            ),
          AmountRow(label: 'Subtotal', amount: transaction.grossAmount),
          if (transaction.totalServiceCharge != 0)
            AmountRow(
              label: 'Biaya layanan',
              sublabel: '${_number(transaction.serviceChargePercentage)}%',
              amount: transaction.totalServiceCharge,
            ),
          if (transaction.totalTax != 0)
            AmountRow(label: 'Pajak', amount: transaction.totalTax),
          if (transaction.totalRounding != 0)
            AmountRow(label: 'Pembulatan', amount: transaction.totalRounding),
          const _ReceiptRule(),
          AmountRow(
            label: 'TOTAL',
            amount: transaction.totalAmount,
            emphasis: AmountEmphasis.total,
          ),
          const _ReceiptRule(),
          _valueRow('Metode pembayaran', transaction.paymentMethod),
          ...transaction.payments.map(
            (payment) => _valueRow(
              payment.paymentMethod,
              Money.format(payment.amountPaid),
            ),
          ),
          if (transaction.isCash) ...[
            AmountRow(label: 'Tunai', amount: transaction.cashTendered),
            AmountRow(label: 'Kembalian', amount: transaction.cashChange),
          ],
          if (_hasText(transaction.queueNumber)) ...[
            const _ReceiptRule(),
            const Text('Nomor antrean', textAlign: TextAlign.center),
            Text(
              transaction.queueNumber!.trim(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
          if (_hasText(footerText)) ...[
            const _ReceiptRule(),
            Text(footerText!.trim(), textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );

  Widget _header(BuildContext context) => Column(
    children: [
      if (_hasText(merchant.logoAssetPath))
        Image.asset(merchant.logoAssetPath!, height: 48, fit: BoxFit.contain),
      Text(
        merchant.name,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      if (_hasText(merchant.address))
        Text(merchant.address!.trim(), textAlign: TextAlign.center),
      if (_hasText(merchant.address2))
        Text(merchant.address2!.trim(), textAlign: TextAlign.center),
    ],
  );

  Widget _line(TransactionLine line) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${line.qty}x', textAlign: TextAlign.center),
            ),
            Expanded(child: Text(line.productName)),
            Text(Money.format(line.totalPrice)),
          ],
        ),
        if (line.qty > 1)
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text('@ ${Money.format(line.price)}'),
          ),
        ..._details(line, TransactionLineDetail.typeVariant),
        ..._details(line, TransactionLineDetail.typeModifier),
      ],
    ),
  );

  Iterable<Widget> _details(TransactionLine line, String type) {
    final sorted =
        line.details.where((detail) => detail.detailType == type).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted.map(
      (detail) => Padding(
        padding: const EdgeInsets.only(left: 34, top: 2),
        child: Text(
          '• ${detail.name}${detail.priceAdjustment == 0 ? '' : ' (${Money.format(detail.priceAdjustment)})'}',
        ),
      ),
    );
  }

  Widget _valueRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

class _ReceiptRule extends StatelessWidget {
  const _ReceiptRule();

  @override
  Widget build(BuildContext context) => const Divider(height: 16);
}
