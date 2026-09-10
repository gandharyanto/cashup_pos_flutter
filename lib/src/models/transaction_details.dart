import '../util/num_utils.dart';

/// The money breakdown the backend stores for a transaction.
class TransactionPricing {
  const TransactionPricing({
    this.baseAmount = 0,
    this.variantTotal = 0,
    this.modifierTotal = 0,
    this.grossAmount = 0,
    this.discountTotal = 0,
    this.promotionTotal = 0,
    this.voucherTotal = 0,
    this.netAmount = 0,
    this.serviceChargePercentage = 0,
    this.serviceChargeTotal = 0,
    this.taxTotal = 0,
    this.roundingType = 'NONE',
    this.roundingTarget = '0',
    this.roundingTotal = 0,
    this.totalAmount = 0,
  });

  final double baseAmount;
  final double variantTotal;
  final double modifierTotal;
  final double grossAmount;
  final double discountTotal;
  final double promotionTotal;
  final double voucherTotal;
  final double netAmount;
  final double serviceChargePercentage;
  final double serviceChargeTotal;
  final double taxTotal;
  final String roundingType;
  final String roundingTarget;
  final double roundingTotal;
  final double totalAmount;

  factory TransactionPricing.fromJson(Map<String, dynamic> json) =>
      TransactionPricing(
        baseAmount: asDouble(json['baseAmount']) ?? 0,
        variantTotal: asDouble(json['variantTotal']) ?? 0,
        modifierTotal: asDouble(json['modifierTotal']) ?? 0,
        grossAmount: asDouble(json['grossAmount']) ?? 0,
        discountTotal: asDouble(json['discountTotal']) ?? 0,
        promotionTotal: asDouble(json['promotionTotal']) ?? 0,
        voucherTotal: asDouble(json['voucherTotal']) ?? 0,
        netAmount: asDouble(json['netAmount']) ?? 0,
        serviceChargePercentage: asDouble(json['serviceChargePercentage']) ?? 0,
        serviceChargeTotal: asDouble(json['serviceChargeTotal']) ?? 0,
        taxTotal: asDouble(json['taxTotal']) ?? 0,
        roundingType: json['roundingType'] as String? ?? 'NONE',
        roundingTarget: json['roundingTarget']?.toString() ?? '0',
        roundingTotal: asDouble(json['roundingTotal']) ?? 0,
        totalAmount: asDouble(json['totalAmount']) ?? 0,
      );
}

/// Which discount was applied, for the receipt's discount label.
class TransactionDiscountInfo {
  const TransactionDiscountInfo({
    this.discountId,
    this.discountName,
    this.discountValueType,
    this.discountValue,
    this.discountScope,
  });

  final int? discountId;
  final String? discountName;
  final String? discountValueType;
  final double? discountValue;
  final String? discountScope;

  factory TransactionDiscountInfo.fromJson(Map<String, dynamic> json) =>
      TransactionDiscountInfo(
        discountId: asInt(json['discountId']),
        discountName: json['discountName'] as String?,
        discountValueType: json['discountValueType'] as String?,
        discountValue: asDouble(json['discountValue']),
        discountScope: json['discountScope'] as String?,
      );
}

/// A settled payment against a transaction.
class PaymentEntry {
  const PaymentEntry({
    required this.transactionId,
    required this.paymentMethod,
    required this.amountPaid,
    required this.status,
    required this.paymentReference,
    required this.paymentDate,
    this.paymentTrxId,
  });

  final int transactionId;
  final String? paymentTrxId;
  final String paymentMethod;
  final double amountPaid;
  final String status;
  final String paymentReference;
  final String paymentDate;

  factory PaymentEntry.fromJson(Map<String, dynamic> json) => PaymentEntry(
    transactionId: asInt(json['transactionId']) ?? 0,
    paymentTrxId: json['paymentTrxId'] as String?,
    paymentMethod: json['paymentMethod'] as String? ?? '',
    amountPaid: asDouble(json['amountPaid']) ?? 0,
    status: json['status'] as String? ?? '',
    paymentReference: json['paymentReference'] as String? ?? '',
    paymentDate: json['paymentDate'] as String? ?? '',
  );
}

/// A variant or modifier recorded against a transaction line.
class TransactionLineDetail {
  const TransactionLineDetail({
    required this.detailType,
    required this.name,
    required this.groupName,
    required this.referenceId,
    required this.groupReferenceId,
    required this.priceAdjustment,
    required this.qty,
    required this.sortOrder,
  });

  static const String typeVariant = 'VARIANT';
  static const String typeModifier = 'MODIFIER';

  final String detailType;
  final String name;
  final String groupName;
  final int referenceId;
  final int groupReferenceId;
  final double priceAdjustment;
  final int qty;
  final int sortOrder;

  factory TransactionLineDetail.fromJson(Map<String, dynamic> json) =>
      TransactionLineDetail(
        detailType: json['detailType'] as String? ?? typeModifier,
        name: json['name'] as String? ?? '',
        groupName: json['groupName'] as String? ?? '',
        referenceId: asInt(json['referenceId']) ?? 0,
        groupReferenceId: asInt(json['groupReferenceId']) ?? 0,
        priceAdjustment: asDouble(json['priceAdjustment']) ?? 0,
        qty: asInt(json['qty']) ?? 0,
        sortOrder: asInt(json['sortOrder']) ?? 0,
      );
}

/// A discount recorded against a transaction line.
class TransactionLineDiscount {
  const TransactionLineDiscount({
    required this.id,
    required this.type,
    required this.value,
    required this.amt,
  });

  final int id;
  final String type;
  final double value;
  final double amt;

  factory TransactionLineDiscount.fromJson(Map<String, dynamic> json) =>
      TransactionLineDiscount(
        id: asInt(json['id']) ?? 0,
        type: json['type'] as String? ?? '',
        value: asDouble(json['value']) ?? 0,
        amt: asDouble(json['amt']) ?? 0,
      );
}

/// A sold line, as stored by the backend.
class TransactionLine {
  const TransactionLine({
    required this.productId,
    required this.productName,
    this.price = 0,
    this.qty = 0,
    this.grossLineTotal = 0,
    this.totalPrice = 0,
    this.taxName,
    this.taxPercentage,
    this.taxAmount,
    this.discounts = const [],
    this.details = const [],
  });

  final int productId;
  final String productName;

  /// Base unit price, before variants and modifiers.
  final double price;
  final int qty;

  /// Base plus variants and modifiers, for the whole line.
  final double grossLineTotal;
  final double totalPrice;
  final String? taxName;
  final double? taxPercentage;
  final double? taxAmount;
  final List<TransactionLineDiscount> discounts;
  final List<TransactionLineDetail> details;

  /// `Large (+10000)`, variants only, in sort order.
  String get variantSummary => _summaryOf(TransactionLineDetail.typeVariant);

  /// `Boba (+3000)`, modifiers only, in sort order.
  String get modifierSummary => _summaryOf(TransactionLineDetail.typeModifier);

  /// Both summaries joined for a single receipt or cart line.
  String get detailSummary =>
      [variantSummary, modifierSummary].where((s) => s.isNotEmpty).join(' • ');

  String _summaryOf(String detailType) {
    final matching =
        details.where((d) => d.detailType == detailType).toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return matching
        .map(
          (d) => d.priceAdjustment > 0
              ? '${d.name} (+${d.priceAdjustment.toInt()})'
              : d.name,
        )
        .join(', ');
  }

  factory TransactionLine.fromJson(Map<String, dynamic> json) =>
      TransactionLine(
        productId: asInt(json['productId']) ?? 0,
        productName: json['productName'] as String? ?? '',
        price: asDouble(json['price']) ?? 0,
        qty: asInt(json['qty']) ?? 0,
        grossLineTotal: asDouble(json['grossLineTotal']) ?? 0,
        totalPrice: asDouble(json['totalPrice']) ?? 0,
        taxName: json['taxName'] as String?,
        taxPercentage: asDouble(json['taxPercentage']),
        taxAmount: asDouble(json['taxAmount']),
        discounts:
            (json['discounts'] as List?)
                ?.whereType<Map>()
                .map(
                  (e) => TransactionLineDiscount.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(growable: false) ??
            const [],
        details:
            (json['details'] as List?)
                ?.whereType<Map>()
                .map(
                  (e) => TransactionLineDetail.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(growable: false) ??
            const [],
      );
}

/// A full transaction, from `pos/transaction/detail/{id}`.
///
/// The convenience getters delegate to [pricing] so callers do not have to
/// null-check it on every read — they mirror the `@IgnoredOnParcel` accessors
/// on the Kotlin `TransactionDetails`.
class TransactionDetails {
  const TransactionDetails({
    required this.transactionId,
    required this.code,
    required this.status,
    required this.paymentMethod,
    required this.transactionDate,
    this.priceIncludeTax = false,
    this.queueNumber,
    this.notes,
    this.pricing,
    this.discount,
    this.cashTendered = 0,
    this.cashChange = 0,
    this.transactionItems = const [],
    this.payments = const [],
  });

  final int transactionId;
  final String code;
  final String status;
  final String paymentMethod;
  final bool priceIncludeTax;
  final String transactionDate;
  final String? queueNumber;
  final String? notes;
  final TransactionPricing? pricing;
  final TransactionDiscountInfo? discount;
  final double cashTendered;
  final double cashChange;
  final List<TransactionLine> transactionItems;
  final List<PaymentEntry> payments;

  /// Falls back to summing line totals, because older transactions predate
  /// the `pricing` block.
  double get grossAmount =>
      pricing?.grossAmount ??
      transactionItems.fold<double>(0, (sum, i) => sum + i.grossLineTotal);

  double get totalTax => pricing?.taxTotal ?? 0;
  double get totalServiceCharge => pricing?.serviceChargeTotal ?? 0;
  double get totalRounding => pricing?.roundingTotal ?? 0;
  double get totalAmount => pricing?.totalAmount ?? 0;
  double get discountAmount => pricing?.discountTotal ?? 0;
  double get promotionAmount => pricing?.promotionTotal ?? 0;
  double get serviceChargePercentage => pricing?.serviceChargePercentage ?? 0;
  String? get discountName => discount?.discountName;

  bool get isCash => paymentMethod.toUpperCase() == 'CASH';

  factory TransactionDetails.fromJson(Map<String, dynamic> json) =>
      TransactionDetails(
        transactionId: asInt(json['transactionId']) ?? 0,
        code: json['code'] as String? ?? '',
        status: json['status'] as String? ?? '',
        paymentMethod: json['paymentMethod'] as String? ?? '',
        priceIncludeTax: asBool(json['priceIncludeTax']) ?? false,
        transactionDate: json['transactionDate'] as String? ?? '',
        queueNumber: json['queueNumber']?.toString(),
        notes: json['notes'] as String?,
        pricing: json['pricing'] is Map
            ? TransactionPricing.fromJson(
                Map<String, dynamic>.from(json['pricing'] as Map),
              )
            : null,
        discount: json['discount'] is Map
            ? TransactionDiscountInfo.fromJson(
                Map<String, dynamic>.from(json['discount'] as Map),
              )
            : null,
        cashTendered: asDouble(json['cashTendered']) ?? 0,
        cashChange: asDouble(json['cashChange']) ?? 0,
        transactionItems:
            (json['transactionItems'] as List?)
                ?.whereType<Map>()
                .map(
                  (e) => TransactionLine.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList(growable: false) ??
            const [],
        payments:
            (json['payments'] as List?)
                ?.whereType<Map>()
                .map((e) => PaymentEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false) ??
            const [],
      );
}

/// What `pos/transaction/create` returns.
class CreatedTransaction {
  const CreatedTransaction({
    required this.id,
    required this.trxId,
    this.queueNumber,
  });

  final int id;
  final String trxId;
  final String? queueNumber;

  factory CreatedTransaction.fromJson(Map<String, dynamic> json) =>
      CreatedTransaction(
        id: asInt(json['id']) ?? 0,
        trxId: json['trxId'] as String? ?? '',
        queueNumber: json['queueNumber']?.toString(),
      );
}
