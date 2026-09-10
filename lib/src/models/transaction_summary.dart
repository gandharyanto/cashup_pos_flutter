import '../util/num_utils.dart';

/// A row of `pos/transaction/list`.
///
/// `totalAmount` arrives as a preformatted string; [totalAmountValue] parses
/// it for callers that need to compute rather than display.
class TransactionSummaryRow {
  const TransactionSummaryRow({
    this.id,
    this.code,
    this.trxId,
    this.paymentMethod,
    this.status,
    this.totalAmount,
    this.transactionDate,
    this.transactionType,
    this.queueNumber,
  });

  final int? id;
  final String? code;
  final String? trxId;
  final String? paymentMethod;
  final String? status;
  final String? totalAmount;
  final String? transactionDate;
  final String? transactionType;
  final String? queueNumber;

  double get totalAmountValue => asDouble(totalAmount) ?? 0;

  factory TransactionSummaryRow.fromJson(Map<String, dynamic> json) =>
      TransactionSummaryRow(
        id: asInt(json['id']),
        code: json['code'] as String?,
        trxId: json['trxId'] as String?,
        paymentMethod: json['paymentMethod'] as String?,
        status: json['status'] as String?,
        totalAmount: json['totalAmount']?.toString(),
        transactionDate: json['transactionDate'] as String?,
        transactionType: json['transactionType'] as String?,
        queueNumber: json['queueNumber']?.toString(),
      );
}
