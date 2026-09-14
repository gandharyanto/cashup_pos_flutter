/// The outcome of a host-executed card / EDC / CDCP payment.
library;

/// What the host reports back after running a card / EDC / CDCP payment
/// through [PosPaymentHandler.pay].
///
/// This is a pure value type: it carries no reference to `dio` or to
/// [PosException] (`lib/src/data/pos_exception.dart`). A host application
/// reports a transport or gateway failure through [PosPaymentResult.failed]
/// with its own [message] and [code] rather than rethrowing an SDK error
/// type.
///
/// [isSuccess] and [isCancelled] are derived from a private discriminator,
/// not from whether [reference] or [message] happen to be null — a success
/// with no [reference] is still a success, and a failure with no [message]
/// is still a failure.
class PosPaymentResult {
  /// The payment completed and the host's gateway approved it.
  ///
  /// [reference] is the host's transaction/trace reference; it is required
  /// because every successful gateway call returns one, even if it is later
  /// unused.
  const PosPaymentResult.success({
    required this.reference,
    this.approvalCode,
    this.cardMasked,
    this.raw,
  }) : message = null,
       code = null,
       _outcome = _Outcome.success;

  /// The payment did not complete: the gateway declined it, the terminal
  /// errored, or the host could not reach it.
  ///
  /// [message] is shown to the cashier, so the host should populate it with
  /// Indonesian copy suitable for direct display.
  const PosPaymentResult.failed({required this.message, this.code, this.raw})
    : reference = null,
      approvalCode = null,
      cardMasked = null,
      _outcome = _Outcome.failed;

  /// The cashier or the terminal operator cancelled the payment before it
  /// completed. Distinct from [failed]: the SDK does not surface this as an
  /// error to report, it simply returns to the payment method selection.
  const PosPaymentResult.cancelled()
    : reference = null,
      approvalCode = null,
      cardMasked = null,
      message = null,
      code = null,
      raw = null,
      _outcome = _Outcome.cancelled;

  /// The gateway's transaction reference or trace number. Set only on
  /// [success].
  final String? reference;

  /// The card network's approval code (e.g. an EDC's "00"). Set only on
  /// [success], and only when the terminal returns one.
  final String? approvalCode;

  /// The masked PAN (e.g. `"411111******1111"`), when the terminal reports
  /// one. Set only on [success].
  final String? cardMasked;

  /// Cashier-facing failure copy. Set only on [failed].
  final String? message;

  /// The gateway or terminal's own error code, when it reports one. Set
  /// only on [failed].
  final String? code;

  /// The raw host/gateway response, kept for logging. Never parsed by the
  /// SDK.
  final Map<String, dynamic>? raw;

  final _Outcome _outcome;

  /// True for a payment the gateway approved.
  bool get isSuccess => _outcome == _Outcome.success;

  /// True when the cashier or terminal cancelled the payment before
  /// completion — not a failure to report.
  bool get isCancelled => _outcome == _Outcome.cancelled;
}

enum _Outcome { success, failed, cancelled }
