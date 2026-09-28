import 'package:cashup_pos/cashup_pos.dart';
import 'package:cashup_pos_example/demo_payment_handler.dart';
import 'package:cashup_pos_example/demo_qris_gateway.dart';
import 'package:cashup_pos_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen offers every launcher entry point', (tester) async {
    await tester.pumpWidget(const DemoHostApp());

    expect(find.text('Buka POS'), findsOneWidget);
    expect(find.text('Riwayat Transaksi'), findsOneWidget);
    expect(find.text('Kelola Produk'), findsOneWidget);
    expect(find.text('Pengaturan Pembayaran'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  test('DemoQrisGateway reports paid on the third status check', () async {
    final gateway = DemoQrisGateway();
    final payload = await gateway.generate(amount: 10000);

    Future<QrisStatus> check() =>
        gateway.checkStatus(invoiceNumber: payload.invoiceNumber);

    expect(await check(), QrisStatus.pending);
    expect(await check(), QrisStatus.pending);
    expect(await check(), QrisStatus.paid);
    expect(await check(), QrisStatus.paid);
  });

  test('DemoPaymentHandler approves supported payments', () async {
    const handler = DemoPaymentHandler(delay: Duration.zero);

    final result = await handler.pay(
      method: 'CARD',
      amount: 25000,
      merchantTrxId: 'POS-1',
    );

    expect(handler.supportedMethods, contains('CARD'));
    expect(result.isSuccess, isTrue);
    expect(result.reference, 'DEMO-POS-1');
  });
}
