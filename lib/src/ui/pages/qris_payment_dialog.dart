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

/// Statuses that stop polling. Mirrors the Kotlin source of truth
/// (`QrisPaymentDialog.kt`, `checkPaymentStatus`): it only calls
/// `stopStatusChecking()` for the paid branch (`status == "OK" ||
/// status == "SUCCESS" || code == "0010"`) and the failed branch
/// (`status == "FAILED" || code == "0020"`); every other status — expired
/// included — falls through its `when` with a `// Continue checking for
/// other statuses` comment, i.e. polling keeps going.
const _terminalStatuses = {QrisStatus.paid, QrisStatus.failed};

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

  /// Set synchronously the instant the user cancels — before
  /// `Navigator.pop` runs — so it is true for the remainder of this
  /// object's life. Every async continuation that could touch
  /// `Navigator`/`setState` (the tail of `_generate` and `_poll`) checks
  /// this first, not just `mounted`: `mounted` stays true for as long as
  /// the dialog's exit transition is still animating, which is exactly the
  /// window where a `checkStatus()` call already in flight can resolve and
  /// try to pop a second time — popping whatever route now sits on top
  /// since the QRIS route is already gone. `_closed` closes that window.
  bool _closed = false;

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
      if (_closed || !mounted) return;
      setState(() => payload = generated);
      // Kotlin fires the first status check immediately once the QR is
      // shown (`handleQRGenerated` -> `startStatusChecking`, which posts
      // its `Runnable` right away), then every `pollInterval` after that.
      // Fire-and-forget: `_poll` guards itself with `_closed`/`mounted`.
      unawaited(_poll());
      timer = Timer.periodic(widget.pollInterval, (_) => _poll());
    } catch (caught) {
      if (_closed || !mounted) return;
      setState(() => error = caught);
    }
  }

  Future<void> _poll() async {
    if (_closed) return;
    final current = payload;
    if (current == null || polling) return;
    polling = true;
    try {
      final next = await widget.gateway.checkStatus(
        invoiceNumber: current.invoiceNumber,
        merchantTrxId: widget.merchantTrxId,
      );
      // Re-check after the await: cancel may have happened while this
      // call was in flight. Discard a stale result rather than act on it.
      if (_closed || !mounted) return;
      setState(() => status = next);
      if (_terminalStatuses.contains(next)) {
        timer?.cancel();
        _closed = true;
        Navigator.pop(context, next);
      }
    } finally {
      polling = false;
    }
  }

  void _cancel() {
    timer?.cancel();
    _closed = true;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PosDialog(
    title: 'Pembayaran QRIS',
    onClose: _cancel,
    child: SizedBox(
      width: 320,
      child: error != null
          ? const Text('Gagal membuat QR. Coba lagi.')
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
