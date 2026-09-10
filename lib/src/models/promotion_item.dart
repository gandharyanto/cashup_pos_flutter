import '../util/num_utils.dart';
import 'discount_item.dart' show idsFrom;

/// When a promotion is allowed to run.
class PromotionSchedule {
  const PromotionSchedule({
    this.startDate,
    this.endDate,
    this.activeDays = const [],
    this.startTime,
    this.endTime,
  });

  final String? startDate;
  final String? endDate;

  /// `MON`…`SUN`. Empty means every day.
  final List<String> activeDays;

  /// `HH:mm`. Null means no time restriction.
  final String? startTime;
  final String? endTime;

  factory PromotionSchedule.fromJson(Map<String, dynamic> json) =>
      PromotionSchedule(
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        activeDays:
            (json['activeDays'] as List?)?.whereType<String>().toList(
              growable: false,
            ) ??
            const [],
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
      );
}

/// A promotion the engine evaluates automatically, from
/// `pos/promotion/active`.
///
/// Two field names differ from the wire format and must not be "corrected":
/// `minimumSubtotal` arrives as [minPurchase], and `rewardQty` becomes the
/// calculator's `getQty`.
class PromotionItem {
  const PromotionItem({
    required this.id,
    required this.name,
    required this.promoType,
    this.priority = 100,
    this.canCombine = false,
    this.valueType,
    this.value,
    this.maxDiscountAmount,
    this.minPurchase = 0,
    this.buyQty,
    this.rewardQty,
    this.rewardType,
    this.rewardValue,
    this.rewardValueType,
    this.rewardDiscountValue,
    this.isMultiplied = false,
    this.buyProductIds = const [],
    this.buyCategoryIds = const [],
    this.rewardProductIds = const [],
    this.rewardCategoryIds = const [],
    this.startDate,
    this.endDate,
    this.schedule,
  });

  static const String typeDiscountByOrder = 'DISCOUNT_BY_ORDER';
  static const String typeDiscountByItemSubtotal = 'DISCOUNT_BY_ITEM_SUBTOTAL';
  static const String typeBuyXGetY = 'BUY_X_GET_Y';

  static const String rewardFree = 'FREE';
  static const String rewardPercentage = 'PERCENTAGE';
  static const String rewardAmount = 'AMOUNT';
  static const String rewardFixedPrice = 'FIXED_PRICE';

  final int id;
  final String name;
  final String promoType;

  /// Lower runs first.
  final int priority;

  /// When false, this promotion stops evaluation once it applies.
  final bool canCombine;

  final String? valueType;
  final double? value;
  final double? maxDiscountAmount;

  /// Wire key: `minimumSubtotal`.
  final double minPurchase;

  final int? buyQty;

  /// Wire key: `rewardQty`. Becomes the calculator's `getQty`.
  final int? rewardQty;

  final String? rewardType;
  final double? rewardValue;

  /// `DISCOUNT_BY_ORDER` carries its value here rather than in [valueType].
  final String? rewardValueType;
  final double? rewardDiscountValue;

  final bool isMultiplied;
  final List<int> buyProductIds;
  final List<int> buyCategoryIds;
  final List<int> rewardProductIds;
  final List<int> rewardCategoryIds;
  final String? startDate;
  final String? endDate;
  final PromotionSchedule? schedule;

  bool get isBuyXGetY => promoType == typeBuyXGetY;
  bool get isFreeReward => rewardType == rewardFree;

  factory PromotionItem.fromJson(Map<String, dynamic> json) => PromotionItem(
    id: asInt(json['id']) ?? 0,
    name: json['name'] as String? ?? '',
    promoType: json['promoType'] as String? ?? '',
    priority: asInt(json['priority']) ?? 100,
    canCombine: asBool(json['canCombine']) ?? false,
    valueType: json['valueType'] as String?,
    value: asDouble(json['value']),
    maxDiscountAmount: asDouble(json['maxDiscountAmount']),
    minPurchase: asDouble(json['minimumSubtotal']) ?? 0,
    buyQty: asInt(json['buyQty']),
    rewardQty: asInt(json['rewardQty']),
    rewardType: json['rewardType'] as String?,
    rewardValue: asDouble(json['rewardValue']),
    rewardValueType: json['rewardValueType'] as String?,
    rewardDiscountValue: asDouble(json['rewardDiscountValue']),
    isMultiplied: asBool(json['isMultiplied']) ?? false,
    buyProductIds: idsFrom(json['buyProductIds'], json['buyProducts']),
    buyCategoryIds: idsFrom(json['buyCategoryIds'], json['buyCategories']),
    rewardProductIds: idsFrom(json['rewardProductIds'], json['rewardProducts']),
    rewardCategoryIds: idsFrom(
      json['rewardCategoryIds'],
      json['rewardCategories'],
    ),
    startDate: json['startDate'] as String?,
    endDate: json['endDate'] as String?,
    schedule: json['schedule'] is Map
        ? PromotionSchedule.fromJson(
            Map<String, dynamic>.from(json['schedule'] as Map),
          )
        : null,
  );

  static List<PromotionItem> listFromJson(Object? data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => PromotionItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
