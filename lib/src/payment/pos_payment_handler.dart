import 'payment_result.dart';

/// Implemented by the host application. The SDK calls this and waits.
abstract class PosPaymentHandler {
  /// Payment methods this host can actually execute, e.g. {'CARD', 'CDCP'}.
  Set<String> get supportedMethods;

  Future<PosPaymentResult> pay({
    required String method,
    required double amount,
    required String merchantTrxId,
    int? transactionId,
  });
}
