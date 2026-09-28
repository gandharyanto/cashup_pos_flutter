import 'package:cashup_pos/cashup_pos.dart';

/// A stand-in for the host's real QRIS integration.
///
/// A production host calls its payment gateway here — the QR payload
/// usually arrives DUKPT-encrypted and is decrypted natively, which is why
/// this is host code rather than SDK code. The SDK owns the dialog, the QR
/// rendering and the 3-second polling loop; it only calls these two
/// methods.
///
/// This demo returns a fixed QR string and reports the payment as
/// [QrisStatus.pending] on the first two status checks and
/// [QrisStatus.paid] from the third onward, so the dialog visibly polls
/// before completing.
class DemoQrisGateway implements QrisGateway {
  DemoQrisGateway({this.pollsUntilPaid = 3});

  /// The status check on which the payment is reported as paid.
  final int pollsUntilPaid;

  /// Status-check counts, keyed by invoice number, so each sale polls
  /// independently of any earlier one.
  final Map<String, int> _checks = {};

  static const _demoQrString =
      '00020101021226610016ID.CO.CASHUP.WWW0118936000000000000000'
      '0215DEMO000000000005204599953033605802ID5909TOKO DEMO6007JAKARTA'
      '6304ABCD';

  @override
  Future<QrisPayload> generate({
    required double amount,
    String? merchantTrxId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // The QR string is static; the invoice number is unique per sale so the
    // poll counter below starts fresh for every QRIS payment.
    final invoiceNumber = 'DEMO-INV-${DateTime.now().millisecondsSinceEpoch}';
    return QrisPayload(qrString: _demoQrString, invoiceNumber: invoiceNumber);
  }

  @override
  Future<QrisStatus> checkStatus({
    required String invoiceNumber,
    String? merchantTrxId,
  }) async {
    final count = (_checks[invoiceNumber] ?? 0) + 1;
    _checks[invoiceNumber] = count;
    return count < pollsUntilPaid ? QrisStatus.pending : QrisStatus.paid;
  }
}
