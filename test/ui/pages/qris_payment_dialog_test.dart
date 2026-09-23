import 'package:cashup_pos/src/payment/qris_gateway.dart';
import 'package:cashup_pos/src/ui/pages/qris_payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class FakeGateway implements QrisGateway {
  int checks = 0;
  QrisStatus status = QrisStatus.pending;
  @override
  Future<QrisPayload> generate({
    required double amount,
    String? merchantTrxId,
  }) async => const QrisPayload(qrString: '000201test', invoiceNumber: 'INV1');
  @override
  Future<QrisStatus> checkStatus({
    required String invoiceNumber,
    String? merchantTrxId,
  }) async {
    checks++;
    return status;
  }
}

void main() {
  testWidgets('renders QR in a repaint boundary and polls until paid', (
    tester,
  ) async {
    final gateway = FakeGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrisPaymentDialog(
            gateway: gateway,
            amount: 10000,
            pollInterval: const Duration(milliseconds: 100),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(QrImageView),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );

    gateway.status = QrisStatus.paid;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(gateway.checks, 1);
  });
}
