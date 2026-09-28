/// Implemented by the host because the QR payload arrives DUKPT-encrypted and
/// decryption is native. The SDK owns the dialog, the QR rendering and the
/// polling loop; the host owns only these two calls.
abstract class QrisGateway {
  Future<QrisPayload> generate({required double amount, String? merchantTrxId});
  Future<QrisStatus> checkStatus({
    required String invoiceNumber,
    String? merchantTrxId,
  });
}

class QrisPayload {
  const QrisPayload({required this.qrString, required this.invoiceNumber});
  final String qrString;
  final String invoiceNumber;
}

enum QrisStatus { pending, paid, failed, expired }
