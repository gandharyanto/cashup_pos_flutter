/// The host-implemented contract for QRIS payload generation and status
/// polling.
library;

/// Implemented by the host application because the QRIS payload arrives
/// DUKPT-encrypted and decryption is native code that cannot live in a
/// Flutter package.
///
/// The SDK owns everything else about QRIS: the payment dialog, rendering
/// the QR code (`qr_flutter`), and the 3-second polling loop that calls
/// [checkStatus] repeatedly until a terminal [QrisStatus] is reached. Both
/// methods here are designed to be called that way — [generate] is called
/// once per payment attempt, [checkStatus] is called on a timer with no
/// side effects other than the host's own network round trip, so the SDK
/// can poll it safely.
abstract class QrisGateway {
  /// Requests a QRIS payload for [amount] from the host's gateway.
  ///
  /// [merchantTrxId] is the SDK-generated identifier for this payment
  /// attempt, for the host to pass through to its gateway and correlate
  /// with backend records.
  ///
  /// Called once at the start of a QRIS payment; the SDK then displays the
  /// returned [QrisPayload] and begins polling [checkStatus].
  Future<QrisPayload> generate({required double amount, String? merchantTrxId});

  /// Polls the current status of the QRIS payment identified by
  /// [invoiceNumber] (from the [QrisPayload] returned by [generate]).
  ///
  /// Safe to call repeatedly with no side effects beyond the host's own
  /// lookup — the SDK calls this on a fixed interval until it observes
  /// [QrisStatus.paid], [QrisStatus.failed] or [QrisStatus.expired].
  /// [merchantTrxId] is passed through unchanged from [generate] so the
  /// host can correlate the poll with the original request.
  Future<QrisStatus> checkStatus({
    required String invoiceNumber,
    String? merchantTrxId,
  });
}

/// The QR payload for a QRIS payment attempt, ready for the SDK to render.
class QrisPayload {
  /// Creates a QRIS payload.
  const QrisPayload({required this.qrString, required this.invoiceNumber});

  /// The decrypted QRIS string the SDK renders as a QR code.
  final String qrString;

  /// The invoice/order number identifying this payment attempt, passed
  /// back to [QrisGateway.checkStatus] on every poll.
  final String invoiceNumber;
}

/// The lifecycle states of a QRIS payment attempt, as reported by
/// [QrisGateway.checkStatus].
enum QrisStatus {
  /// The customer has not yet scanned or settled the payment. The SDK
  /// keeps polling.
  pending,

  /// The payment settled successfully. A terminal state.
  paid,

  /// The gateway or issuer declined or errored the payment. A terminal
  /// state.
  failed,

  /// The QR code's validity window elapsed before it was paid. A terminal
  /// state.
  expired,
}
