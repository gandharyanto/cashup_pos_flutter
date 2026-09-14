/// The host-implemented contract for card / EDC / CDCP payments.
library;

import 'payment_result.dart';

/// Implemented by the host application to execute a card, EDC or CDCP
/// payment. The SDK calls [pay] and waits for it to complete; it does not
/// retry and does not interpret the result beyond [PosPaymentResult.isSuccess]
/// and [PosPaymentResult.isCancelled].
///
/// The SDK never talks to a card terminal directly — DUKPT and EDC/CDCP
/// integration are host-specific and often native, so this interface is the
/// seam. A host registers its implementation through `PosConfig`.
abstract class PosPaymentHandler {
  /// The payment method codes this host can actually execute, e.g.
  /// `{'CARD', 'CDCP'}`.
  ///
  /// The SDK uses this to decide which payment method tiles to offer; it
  /// never calls [pay] with a method outside this set.
  Set<String> get supportedMethods;

  /// Runs a payment of [amount] for the given [method] and waits for the
  /// host's gateway or terminal to settle it.
  ///
  /// [merchantTrxId] is the SDK-generated identifier for this attempt, for
  /// the host to pass through to its gateway and to correlate with backend
  /// records. [transactionId] is the backend transaction id once one has
  /// been created, when the host needs it to reconcile with `/pos/*`; it is
  /// null for a payment attempted before the transaction is created.
  ///
  /// Returns once the host has a definite outcome: approved, declined, or
  /// cancelled by the operator. The host reports a gateway or transport
  /// failure through [PosPaymentResult.failed] rather than throwing.
  Future<PosPaymentResult> pay({
    required String method,
    required double amount,
    required String merchantTrxId,
    int? transactionId,
  });
}
