import '../util/num_utils.dart';

/// A named target the backend attaches to a discount or promotion.
class PosTarget {
  const PosTarget({required this.id, required this.name});

  final int id;
  final String name;

  factory PosTarget.fromJson(Map<String, dynamic> json) => PosTarget(
    id: asInt(json['id']) ?? 0,
    name: json['name'] as String? ?? '',
  );
}

/// Extracts ids from a list that may be plain ids or `{id, name}` objects.
///
/// The backend populates `targetProductIds` on some endpoints and only
/// `targetProducts` on others; the Kotlin view models apply the same fallback.
List<int> idsFrom(Object? idList, Object? objectList) {
  final ids = asIntList(idList);
  if (ids.isNotEmpty) return ids;
  if (objectList is! List) return const [];
  return objectList
      .whereType<Map>()
      .map((e) => asInt(e['id']))
      .whereType<int>()
      .toList(growable: false);
}

/// A discount the cashier may apply by hand, from `pos/discount/available`.
///
/// Exactly one discount applies to a transaction — unlike promotions, which
/// the engine evaluates automatically and may combine.
class DiscountItem {
  const DiscountItem({
    required this.id,
    required this.name,
    required this.valueType,
    required this.value,
    required this.scope,
    this.maxDiscountAmount,
    this.minPurchase = 0,
    this.channel,
    this.startDate,
    this.endDate,
    this.usageCount = 0,
    this.usageLimit,
    this.usageRemaining,
    this.categoryIds = const [],
    this.targetProductIds = const [],
  });

  static const String typePercentage = 'PERCENTAGE';
  static const String typeAmount = 'AMOUNT';
  static const String scopeAll = 'ALL';
  static const String scopeProduct = 'PRODUCT';
  static const String scopeCategory = 'CATEGORY';

  final int id;
  final String name;

  /// `PERCENTAGE` or `AMOUNT`.
  final String valueType;

  /// A percentage in 0–100, or a flat rupiah amount.
  final double value;

  /// `ALL`, `PRODUCT` or `CATEGORY`.
  final String scope;

  /// Cap for percentage discounts; `null` means uncapped.
  final double? maxDiscountAmount;
  final double minPurchase;
  final String? channel;
  final String? startDate;
  final String? endDate;
  final int usageCount;
  final int? usageLimit;
  final int? usageRemaining;
  final List<int> categoryIds;
  final List<int> targetProductIds;

  bool get isPercentage => valueType == typePercentage;

  /// Whether the backend has no uses left to grant.
  bool get isExhausted => usageRemaining != null && usageRemaining! <= 0;

  factory DiscountItem.fromJson(Map<String, dynamic> json) => DiscountItem(
    id: asInt(json['id']) ?? 0,
    name: json['name'] as String? ?? '',
    valueType: json['valueType'] as String? ?? typeAmount,
    value: asDouble(json['value']) ?? 0,
    scope: json['scope'] as String? ?? scopeAll,
    maxDiscountAmount: asDouble(json['maxDiscountAmount']),
    minPurchase: asDouble(json['minPurchase']) ?? 0,
    channel: json['channel'] as String?,
    startDate: json['startDate'] as String?,
    endDate: json['endDate'] as String?,
    usageCount: asInt(json['usageCount']) ?? 0,
    usageLimit: asInt(json['usageLimit']),
    usageRemaining: asInt(json['usageRemaining']),
    categoryIds: idsFrom(json['categoryIds'], json['targetCategories']),
    targetProductIds: idsFrom(json['targetProductIds'], json['targetProducts']),
  );

  static List<DiscountItem> listFromJson(Object? data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => DiscountItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
