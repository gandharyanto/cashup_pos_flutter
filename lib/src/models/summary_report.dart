import '../util/num_utils.dart';

/// How many units of one product sold in the reporting period.
class ProductSummaryRow {
  const ProductSummaryRow({
    required this.productName,
    required this.totalSaleItems,
  });

  final String productName;
  final int totalSaleItems;

  factory ProductSummaryRow.fromJson(Map<String, dynamic> json) =>
      ProductSummaryRow(
        productName: json['productName'] as String? ?? '',
        totalSaleItems: asInt(json['totalSaleItems']) ?? 0,
      );
}

/// How much one payment method took in the reporting period.
class PaymentSummaryRow {
  const PaymentSummaryRow({
    required this.paymentName,
    required this.totalTransactions,
    required this.totalAmountTransactions,
  });

  final String paymentName;
  final int totalTransactions;
  final double totalAmountTransactions;

  factory PaymentSummaryRow.fromJson(Map<String, dynamic> json) =>
      PaymentSummaryRow(
        paymentName: json['paymentName'] as String? ?? '',
        totalTransactions: asInt(json['totalTransactions']) ?? 0,
        totalAmountTransactions: asDouble(json['totalAmountTransactions']) ?? 0,
      );
}

/// The `pos/summary-report/list` payload.
class SummaryReportData {
  const SummaryReportData({
    this.productList = const [],
    this.paymentListInternal = const [],
    this.paymentListExternal = const [],
  });

  final List<ProductSummaryRow> productList;
  final List<PaymentSummaryRow> paymentListInternal;
  final List<PaymentSummaryRow> paymentListExternal;

  /// Both payment lists, in the order the receipt prints them.
  List<PaymentSummaryRow> get allPayments => [
    ...paymentListInternal,
    ...paymentListExternal,
  ];

  int get totalTransactions =>
      allPayments.fold(0, (sum, p) => sum + p.totalTransactions);

  double get totalAmount =>
      allPayments.fold(0, (sum, p) => sum + p.totalAmountTransactions);

  bool get isEmpty => productList.isEmpty && allPayments.isEmpty;

  factory SummaryReportData.fromJson(Map<String, dynamic> json) =>
      SummaryReportData(
        productList: _products(json['productList']),
        paymentListInternal: _payments(json['paymentListInternal']),
        paymentListExternal: _payments(json['paymentListExternal']),
      );

  static List<ProductSummaryRow> _products(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => ProductSummaryRow.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static List<PaymentSummaryRow> _payments(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => PaymentSummaryRow.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
