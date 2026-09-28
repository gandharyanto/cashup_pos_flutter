enum _PosPaymentResultType { success, failed, cancelled }

/// What the host reports back after running a card / EDC / CDCP payment.
class PosPaymentResult {
  const PosPaymentResult.success({
    required this.reference,
    this.approvalCode,
    this.cardMasked,
    this.raw,
  }) : _type = _PosPaymentResultType.success,
       message = null,
       code = null;

  const PosPaymentResult.failed({required this.message, this.code, this.raw})
    : _type = _PosPaymentResultType.failed,
      reference = null,
      approvalCode = null,
      cardMasked = null;

  const PosPaymentResult.cancelled()
    : _type = _PosPaymentResultType.cancelled,
      reference = null,
      approvalCode = null,
      cardMasked = null,
      message = null,
      code = null,
      raw = null;

  final _PosPaymentResultType _type;
  final String? reference;
  final String? approvalCode;
  final String? cardMasked;
  final String? message;
  final String? code;
  final Map<String, dynamic>? raw;

  bool get isSuccess => _type == _PosPaymentResultType.success;
  bool get isCancelled => _type == _PosPaymentResultType.cancelled;
}
