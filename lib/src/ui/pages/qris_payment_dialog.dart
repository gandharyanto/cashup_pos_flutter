import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../payment/qris_gateway.dart';
import '../widgets/pos_dialog.dart';

Future<QrisStatus?> showQrisPaymentDialog(
  BuildContext context, {
  required QrisGateway gateway,
  required double amount,
  String? merchantTrxId,
}) => showDialog<QrisStatus>(
  context: context,
  barrierDismissible: false,
  builder: (_) => QrisPaymentDialog(
    gateway: gateway,
    amount: amount,
    merchantTrxId: merchantTrxId,
  ),
);

class QrisPaymentDialog extends StatefulWidget {
  const QrisPaymentDialog({
    super.key,
    required this.gateway,
    required this.amount,
    this.merchantTrxId,
    this.pollInterval = const Duration(seconds: 3),
  });
  final QrisGateway gateway;
  final double amount;
  final String? merchantTrxId;
  final Duration pollInterval;

  @override
  State<QrisPaymentDialog> createState() => _QrisPaymentDialogState();
}

class _QrisPaymentDialogState extends State<QrisPaymentDialog> {
  QrisPayload? payload;
  Object? error;
  QrisStatus status = QrisStatus.pending;
  Timer? timer;
  bool polling = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final generated = await widget.gateway.generate(
        amount: widget.amount,
        merchantTrxId: widget.merchantTrxId,
      );
      if (!mounted) return;
      setState(() => payload = generated);
      timer = Timer.periodic(widget.pollInterval, (_) => _poll());
    } catch (caught) {
      if (mounted) setState(() => error = caught);
    }
  }

  Future<void> _poll() async {
    final current = payload;
    if (current == null || polling) return;
    polling = true;
    try {
      final next = await widget.gateway.checkStatus(
        invoiceNumber: current.invoiceNumber,
        merchantTrxId: widget.merchantTrxId,
      );
      if (!mounted) return;
      setState(() => status = next);
      if (next != QrisStatus.pending) {
        timer?.cancel();
        Navigator.pop(context, next);
      }
    } finally {
      polling = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PosDialog(
    title: 'Pembayaran QRIS',
    onClose: () => Navigator.pop(context),
    child: SizedBox(
      width: 320,
      child: error != null
          ? Text('Gagal membuat QR: $error')
          : payload == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: QrImageView(data: payload!.qrString, size: 240),
                ),
                const SizedBox(height: 12),
                Text(
                  status == QrisStatus.pending
                      ? 'Menunggu pembayaran…'
                      : status.name,
                ),
              ],
            ),
    ),
  );
}
