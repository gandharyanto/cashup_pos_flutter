/// Request models for `pos/transaction/create` and
/// `pos/transaction/update/{merchantTrxId}`.
///
/// Several Dart field names differ from their wire keys, because the wire keys
/// are what the backend validates against:
///
/// | Dart | JSON |
/// |---|---|
/// | `subTotal` | `grossAmount` |
/// | `discountAmount` | `totalDiscount` |
/// | `promotionAmount` | `totalPromotionAmount` |
/// | `promotionIds` | `appliedPromotionIds` |
///
/// Optional fields are **omitted** when null rather than serialized as
/// `null`. The Kotlin client uses Gson defaults, which drop nulls, and the
/// backend validator treats an absent key differently from an explicit null.
library;

/// The service charge block inside [PaymentSettingRequest].
class ServiceChargeRequest {
  const ServiceChargeRequest({required this.type, required this.value});

  /// `PERCENTAGE` or `AMOUNT`.
  final String type;
  final double value;

  Map<String, dynamic> toJson() => {'type': type, 'value': value};
}

/// The payment-setting snapshot sent with a transaction, so the backend can
/// re-run the same calculation the client ran.
class PaymentSettingRequest {
  const PaymentSettingRequest({
    this.priceIncludeTax = false,
    this.serviceCharge,
  });

  final bool priceIncludeTax;
  final ServiceChargeRequest? serviceCharge;

  /// Always true. The engine computes every item's taxable base after its
  /// deduction share, and the backend must be told to do the same.
  bool get taxAppliedAfterDiscount => true;

  Map<String, dynamic> toJson() => {
    'priceIncludeTax': priceIncludeTax,
    'taxAppliedAfterDiscount': taxAppliedAfterDiscount,
    if (serviceCharge != null) 'serviceCharge': serviceCharge!.toJson(),
  };
}

/// A variant or modifier attached to a transaction line.
class RequestItemDetail {
  const RequestItemDetail({
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

  Map<String, dynamic> toJson() => {
    'detailType': detailType,
    'name': name,
    'groupName': groupName,
    'referenceId': referenceId,
    'groupReferenceId': groupReferenceId,
    'priceAdjustment': priceAdjustment,
    'qty': qty,
    'sortOrder': sortOrder,
  };
}

/// One discount row in a line's breakdown.
class ItemDiscountDetail {
  const ItemDiscountDetail({
    required this.id,
    required this.type,
    required this.value,
    required this.amt,
  });

  final int id;
  final String type;
  final double value;
  final String amt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'value': value,
    'amt': amt,
  };
}

/// Why a line participates in a promotion.
class ItemPromotionMeta {
  const ItemPromotionMeta({required this.role, this.buyQty, this.getQty});

  static const String roleQualifier = 'QUALIFIER';
  static const String roleReward = 'REWARD';

  final String role;
  final int? buyQty;
  final int? getQty;

  Map<String, dynamic> toJson() => {
    'role': role,
    if (buyQty != null) 'buyQty': buyQty,
    if (getQty != null) 'getQty': getQty,
  };
}

/// One promotion row in a line's breakdown.
class ItemPromotionDetail {
  const ItemPromotionDetail({
    required this.id,
    required this.type,
    required this.amt,
    this.meta,
  });

  final int id;
  final String type;
  final String amt;
  final ItemPromotionMeta? meta;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amt': amt,
    if (meta != null) 'meta': meta!.toJson(),
  };
}

/// One tax row in a line's breakdown.
class ItemTaxDetail {
  const ItemTaxDetail({
    required this.id,
    required this.type,
    required this.value,
    required this.amt,
  });

  final int id;
  final String type;
  final double value;
  final String amt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'value': value,
    'amt': amt,
  };
}

/// A line of the transaction payload.
///
/// Money fields are pre-formatted strings, not numbers — the calculator
/// renders them with a fixed `0.00` US-decimal pattern so the backend parses
/// exactly what the client computed.
class RequestTransactionItem {
  const RequestTransactionItem({
    required this.productId,
    required this.price,
    required this.qty,
    required this.totalPrice,
    this.productName,
    this.variantId,
    this.variantOptionIds,
    this.details,
    this.taxId,
    this.taxAmount,
    this.discounts,
    this.promotions,
    this.taxes,
    this.isPriceAdjustable,
    this.isPriceOverride,
  });

  final int productId;
  final String? productName;
  final String price;
  final int qty;
  final String totalPrice;
  final int? variantId;
  final List<int>? variantOptionIds;
  final List<RequestItemDetail>? details;

  /// Legacy flat tax fields, kept for the endpoints that still read them.
  final int? taxId;
  final String? taxAmount;

  final List<ItemDiscountDetail>? discounts;
  final List<ItemPromotionDetail>? promotions;
  final List<ItemTaxDetail>? taxes;

  final bool? isPriceAdjustable;
  final bool? isPriceOverride;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    if (productName != null) 'productName': productName,
    'price': price,
    'qty': qty,
    'totalPrice': totalPrice,
    if (variantId != null) 'variantId': variantId,
    if (variantOptionIds != null && variantOptionIds!.isNotEmpty)
      'variantOptionIds': variantOptionIds,
    if (details != null && details!.isNotEmpty)
      'details': details!.map((d) => d.toJson()).toList(growable: false),
    if (taxId != null) 'taxId': taxId,
    if (taxAmount != null) 'taxAmount': taxAmount,
    if (discounts != null && discounts!.isNotEmpty)
      'discounts': discounts!.map((d) => d.toJson()).toList(growable: false),
    if (promotions != null && promotions!.isNotEmpty)
      'promotions': promotions!.map((p) => p.toJson()).toList(growable: false),
    if (taxes != null && taxes!.isNotEmpty)
      'taxes': taxes!.map((t) => t.toJson()).toList(growable: false),
    if (isPriceAdjustable != null) 'isPriceAdjustable': isPriceAdjustable,
    if (isPriceOverride != null) 'isPriceOverride': isPriceOverride,
  };

  /// The first discount amount on this line, used to order items in the
  /// payload the way the backend expects.
  double get firstDiscountAmount =>
      double.tryParse(discounts?.firstOrNull?.amt ?? '') ?? 0;
}

/// The `pos/transaction/create` payload.
class CreateTransactionRequest {
  const CreateTransactionRequest({
    required this.paymentMethod,
    required this.subTotal,
    required this.totalServiceCharge,
    required this.totalTax,
    required this.totalRounding,
    required this.totalAmount,
    required this.transactionItems,
    this.netAmount,
    this.discountAmount,
    this.promotionAmount,
    this.paymentSetting,
    this.discountId,
    this.promotionIds,
    this.cashTendered,
    this.cashChange,
    this.queueNumber,
    this.notes,
  });

  final String paymentMethod;

  /// Wire key: `grossAmount`.
  final String subTotal;
  final String? netAmount;

  /// Wire key: `totalDiscount`.
  final String? discountAmount;

  /// Wire key: `totalPromotionAmount`.
  final String? promotionAmount;

  final String totalServiceCharge;
  final String totalTax;
  final String totalRounding;
  final String totalAmount;
  final PaymentSettingRequest? paymentSetting;
  final int? discountId;

  /// Wire key: `appliedPromotionIds`.
  final List<int>? promotionIds;

  final String? cashTendered;
  final String? cashChange;
  final List<RequestTransactionItem> transactionItems;
  final int? queueNumber;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'paymentMethod': paymentMethod,
    'grossAmount': subTotal,
    if (netAmount != null) 'netAmount': netAmount,
    if (discountAmount != null) 'totalDiscount': discountAmount,
    if (promotionAmount != null) 'totalPromotionAmount': promotionAmount,
    'totalServiceCharge': totalServiceCharge,
    'totalTax': totalTax,
    'totalRounding': totalRounding,
    'totalAmount': totalAmount,
    if (paymentSetting != null) 'paymentSetting': paymentSetting!.toJson(),
    if (discountId != null) 'discountId': discountId,
    if (promotionIds != null && promotionIds!.isNotEmpty)
      'appliedPromotionIds': promotionIds,
    if (cashTendered != null) 'cashTendered': cashTendered,
    if (cashChange != null) 'cashChange': cashChange,
    'transactionItems': transactionItems
        .map((i) => i.toJson())
        .toList(growable: false),
    if (queueNumber != null) 'queueNumber': queueNumber,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}

/// The `pos/transaction/update/{merchantTrxId}` payload, sent once a
/// non-cash payment settles.
class UpdateTransactionRequest {
  const UpdateTransactionRequest({
    required this.paymentMethod,
    required this.amountPaid,
    required this.status,
    required this.paymentReference,
    required this.paymentDate,
    this.paymentTrxId,
  });

  final String? paymentTrxId;
  final String paymentMethod;
  final double amountPaid;
  final String status;
  final String paymentReference;
  final String paymentDate;

  Map<String, dynamic> toJson() => {
    'paymentTrxId': paymentTrxId,
    'paymentMethod': paymentMethod,
    'amountPaid': amountPaid,
    'status': status,
    'paymentReference': paymentReference,
    'paymentDate': paymentDate,
  };
}
