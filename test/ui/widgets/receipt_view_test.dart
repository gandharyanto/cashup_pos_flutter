import 'package:cashup_pos/src/config/pos_config.dart';
import 'package:cashup_pos/src/models/transaction_details.dart';
import 'package:cashup_pos/src/ui/widgets/receipt_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const variant = TransactionLineDetail(
    detailType: TransactionLineDetail.typeVariant,
    name: 'Large',
    groupName: 'Ukuran',
    referenceId: 1,
    groupReferenceId: 1,
    priceAdjustment: 5000,
    qty: 1,
    sortOrder: 1,
  );
  const modifier = TransactionLineDetail(
    detailType: TransactionLineDetail.typeModifier,
    name: 'Boba',
    groupName: 'Topping',
    referenceId: 2,
    groupReferenceId: 2,
    priceAdjustment: 3000,
    qty: 1,
    sortOrder: 0,
  );
  const transaction = TransactionDetails(
    transactionId: 7,
    code: 'TRX-007',
    status: 'PAID',
    paymentMethod: 'CASH',
    transactionDate: '2026-09-24T14:05:03',
    queueNumber: 'A12',
    notes: 'Tanpa sedotan',
    pricing: TransactionPricing(
      grossAmount: 66000,
      discountTotal: 5000,
      promotionTotal: 1000,
      serviceChargePercentage: 5,
      serviceChargeTotal: 3000,
      taxTotal: 6000,
      roundingTotal: 0,
      totalAmount: 69000,
    ),
    discount: TransactionDiscountInfo(discountName: 'Member'),
    cashTendered: 100000,
    cashChange: 31000,
    transactionItems: [
      TransactionLine(
        productId: 1,
        productName: 'Es Kopi Susu',
        price: 25000,
        qty: 2,
        grossLineTotal: 66000,
        totalPrice: 66000,
        details: [modifier, variant],
      ),
    ],
  );

  testWidgets('renders receipt sections in Kotlin parity order', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReceiptView(
              transaction: transaction,
              merchant: PosMerchant(name: 'Cashup Coffee', address: 'Jakarta'),
              footerText: 'Terima kasih',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Cashup Coffee'), findsOneWidget);
    expect(find.text('TRX-007'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('@ Rp 25.000'), findsOneWidget);
    expect(find.text('• Large (Rp 5.000)'), findsOneWidget);
    expect(find.text('• Boba (Rp 3.000)'), findsOneWidget);
    expect(find.text('Catatan: Tanpa sedotan'), findsOneWidget);
    expect(find.text('Diskon (Member)'), findsOneWidget);
    expect(find.text('5%'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text('Kembalian'), findsOneWidget);
    expect(find.text('A12'), findsOneWidget);
    expect(find.text('Terima kasih'), findsOneWidget);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('TRX-007'), lessThan(top('Es Kopi Susu')));
    expect(top('• Large (Rp 5.000)'), lessThan(top('• Boba (Rp 3.000)')));
    expect(top('Catatan: Tanpa sedotan'), lessThan(top('Diskon (Member)')));
    expect(top('TOTAL'), lessThan(top('Metode pembayaran')));
    expect(top('A12'), lessThan(top('Terima kasih')));
  });

  testWidgets('supports 58mm and 80mm paper widths', (tester) async {
    Future<double> render(ReceiptPaperWidth width) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: Center(
              child: ReceiptView(
                transaction: transaction,
                merchant: const PosMerchant(name: 'Merchant'),
                paperWidth: width,
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(ReceiptView)).width;
    }

    expect(await render(ReceiptPaperWidth.mm58), 219);
    expect(await render(ReceiptPaperWidth.mm80), 302);
  });
}
