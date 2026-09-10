import 'package:collection/collection.dart';

import '../models/create_transaction_request.dart';
import '../models/option_group.dart';
import '../models/payment_setting.dart';

const ListEquality<Object?> _listEquality = ListEquality<Object?>();

/// One cart line, in the shape the calculation engine consumes.
///
/// [price] is the **effective** price: base price plus the variant and
/// modifier adjustments. [basePrice] keeps the unadjusted figure, which the
/// transaction payload reports separately.
///
/// Equality covers every field because the checkout controller fingerprints a
/// list of these to decide whether the calculation must run again.
class CartItemData {
  const CartItemData({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    double? basePrice,
    this.taxAmountPerUnit = 0,
    this.isTaxable = false,
    this.taxId,
    this.taxName,
    this.taxPercentage,
    this.variantId,
    this.selectedVariants = const [],
    this.selectedModifiers = const [],
    this.categoryIds = const [],
    String? cartKey,
    this.isPriceAdjustable = false,
    this.isPriceOverride = false,
  }) : _basePrice = basePrice,
       _cartKey = cartKey;

  final int productId;
  final String productName;

  /// `basePrice + variantAdjustments + modifierAdjustments`.
  final double price;

  final double? _basePrice;
  final int quantity;
  final double taxAmountPerUnit;
  final bool isTaxable;
  final int? taxId;
  final String? taxName;
  final double? taxPercentage;
  final int? variantId;
  final List<VariantOption> selectedVariants;
  final List<ModifierOption> selectedModifiers;

  /// Used to evaluate `scope: CATEGORY` discounts and promotions.
  final List<int> categoryIds;

  final String? _cartKey;

  /// True when the product allows the cashier to change its price.
  final bool isPriceAdjustable;

  /// True when the cashier actually did change it on this line.
  final bool isPriceOverride;

  /// The price before variant and modifier adjustments.
  double get basePrice => _basePrice ?? price;

  /// Unique per line. Two lines of the same product with different options
  /// have different keys, and per-line savings are keyed off this.
  String get cartKey => _cartKey ?? productId.toString();

  double get lineSubtotal => price * quantity;

  CartItemData copyWith({int? quantity}) => CartItemData(
    productId: productId,
    productName: productName,
    price: price,
    basePrice: _basePrice,
    quantity: quantity ?? this.quantity,
    taxAmountPerUnit: taxAmountPerUnit,
    isTaxable: isTaxable,
    taxId: taxId,
    taxName: taxName,
    taxPercentage: taxPercentage,
    variantId: variantId,
    selectedVariants: selectedVariants,
    selectedModifiers: selectedModifiers,
    categoryIds: categoryIds,
    cartKey: _cartKey,
    isPriceAdjustable: isPriceAdjustable,
    isPriceOverride: isPriceOverride,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemData &&
          other.productId == productId &&
          other.productName == productName &&
          other.price == price &&
          other.basePrice == basePrice &&
          other.quantity == quantity &&
          other.taxAmountPerUnit == taxAmountPerUnit &&
          other.isTaxable == isTaxable &&
          other.taxId == taxId &&
          other.taxName == taxName &&
          other.taxPercentage == taxPercentage &&
          other.variantId == variantId &&
          _listEquality.equals(other.selectedVariants, selectedVariants) &&
          _listEquality.equals(other.selectedModifiers, selectedModifiers) &&
          _listEquality.equals(other.categoryIds, categoryIds) &&
          other.cartKey == cartKey &&
          other.isPriceAdjustable == isPriceAdjustable &&
          other.isPriceOverride == isPriceOverride;

  @override
  int get hashCode => Object.hash(
    productId,
    productName,
    price,
    basePrice,
    quantity,
    taxAmountPerUnit,
    isTaxable,
    taxId,
    taxPercentage,
    variantId,
    _listEquality.hash(selectedVariants),
    _listEquality.hash(selectedModifiers),
    _listEquality.hash(categoryIds),
    cartKey,
    isPriceAdjustable,
    isPriceOverride,
  );
}

/// A discount the cashier applied, ready for the engine.
///
/// Normally built from a `DiscountItem` returned by
/// `POST /pos/discount/validate`.
class DiscountInput {
  const DiscountInput({
    required this.valueType,
    required this.value,
    this.discountId,
    this.name = '',
    this.maxDiscountAmount,
    this.minPurchase = 0,
    this.scope = scopeAll,
    this.eligibleProductIds = const [],
    this.eligibleCategoryIds = const [],
  });

  static const String typePercentage = 'PERCENTAGE';
  static const String typeAmount = 'AMOUNT';
  static const String scopeAll = 'ALL';
  static const String scopeProduct = 'PRODUCT';
  static const String scopeCategory = 'CATEGORY';

  final int? discountId;
  final String name;

  /// `PERCENTAGE` or `AMOUNT`.
  final String valueType;

  /// A percentage in 0–100, or a flat amount.
  final double value;

  /// Cap for percentage discounts. Null means uncapped.
  final double? maxDiscountAmount;

  final double minPurchase;

  /// `ALL`, `PRODUCT` or `CATEGORY`.
  final String scope;

  final List<int> eligibleProductIds;
  final List<int> eligibleCategoryIds;

  bool get isPercentage => valueType == typePercentage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscountInput &&
          other.discountId == discountId &&
          other.valueType == valueType &&
          other.value == value &&
          other.maxDiscountAmount == maxDiscountAmount &&
          other.minPurchase == minPurchase &&
          other.scope == scope &&
          _listEquality.equals(other.eligibleProductIds, eligibleProductIds) &&
          _listEquality.equals(other.eligibleCategoryIds, eligibleCategoryIds);

  @override
  int get hashCode => Object.hash(
    discountId,
    valueType,
    value,
    maxDiscountAmount,
    minPurchase,
    scope,
    _listEquality.hash(eligibleProductIds),
    _listEquality.hash(eligibleCategoryIds),
  );
}

/// A promotion evaluated automatically against the cart.
///
/// Built from a `PromotionItem` fetched from `GET /pos/promotion/active`.
class PromotionInput {
  const PromotionInput({
    required this.promotionId,
    required this.promoType,
    required this.priority,
    required this.canCombine,
    this.name = '',
    this.valueType,
    this.value,
    this.maxDiscountAmount,
    this.minPurchase = 0,
    this.buyQty,
    this.getQty,
    this.rewardType,
    this.rewardValue,
    this.isMultiplied = false,
    this.buyScope = scopeAll,
    this.buyProductIds = const [],
    this.buyCategoryIds = const [],
    this.rewardScope = scopeAll,
    this.rewardProductIds = const [],
    this.rewardCategoryIds = const [],
    this.selectedRewardQtyMap = const {},
    this.activeDays = const [],
    this.activeStartTime,
    this.activeEndTime,
  });

  static const String typeDiscountByOrder = 'DISCOUNT_BY_ORDER';
  static const String typeDiscountByItemSubtotal = 'DISCOUNT_BY_ITEM_SUBTOTAL';
  static const String typeBuyXGetY = 'BUY_X_GET_Y';

  static const String rewardFree = 'FREE';
  static const String rewardPercentage = 'PERCENTAGE';
  static const String rewardAmount = 'AMOUNT';
  static const String rewardFixedPrice = 'FIXED_PRICE';

  static const String scopeAll = 'ALL';
  static const String scopeProduct = 'PRODUCT';
  static const String scopeCategory = 'CATEGORY';

  final int promotionId;
  final String name;

  /// `DISCOUNT_BY_ORDER`, `BUY_X_GET_Y` or `DISCOUNT_BY_ITEM_SUBTOTAL`.
  final String promoType;

  /// Lower runs first.
  final int priority;

  /// When false, evaluation stops after this promotion applies.
  final bool canCombine;

  final String? valueType;
  final double? value;
  final double? maxDiscountAmount;
  final double minPurchase;

  final int? buyQty;

  /// The reward quantity. Named to match the calculator, not the wire format
  /// (`rewardQty`).
  final int? getQty;

  /// `FREE`, `PERCENTAGE`, `AMOUNT` or `FIXED_PRICE`. `BUY_X_GET_Y` only.
  final String? rewardType;
  final double? rewardValue;

  /// Whether the reward repeats for each full buy cycle.
  final bool isMultiplied;

  /// Which items count toward [buyQty].
  final String buyScope;
  final List<int> buyProductIds;
  final List<int> buyCategoryIds;

  /// Which items may receive the reward.
  final String rewardScope;
  final List<int> rewardProductIds;
  final List<int> rewardCategoryIds;

  /// Reward items the cashier chose: cart key to quantity. Empty means the
  /// engine auto-selects the cheapest eligible units.
  final Map<String, int> selectedRewardQtyMap;

  /// `MON`…`SUN`. Empty means every day.
  final List<String> activeDays;

  /// `HH:mm`. Null means no time restriction.
  final String? activeStartTime;
  final String? activeEndTime;

  bool get isBuyXGetY => promoType == typeBuyXGetY;
  bool get isFreeReward => rewardType == rewardFree;

  PromotionInput copyWith({Map<String, int>? selectedRewardQtyMap}) =>
      PromotionInput(
        promotionId: promotionId,
        name: name,
        promoType: promoType,
        priority: priority,
        canCombine: canCombine,
        valueType: valueType,
        value: value,
        maxDiscountAmount: maxDiscountAmount,
        minPurchase: minPurchase,
        buyQty: buyQty,
        getQty: getQty,
        rewardType: rewardType,
        rewardValue: rewardValue,
        isMultiplied: isMultiplied,
        buyScope: buyScope,
        buyProductIds: buyProductIds,
        buyCategoryIds: buyCategoryIds,
        rewardScope: rewardScope,
        rewardProductIds: rewardProductIds,
        rewardCategoryIds: rewardCategoryIds,
        selectedRewardQtyMap: selectedRewardQtyMap ?? this.selectedRewardQtyMap,
        activeDays: activeDays,
        activeStartTime: activeStartTime,
        activeEndTime: activeEndTime,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromotionInput &&
          other.promotionId == promotionId &&
          other.promoType == promoType &&
          other.priority == priority &&
          other.canCombine == canCombine &&
          other.valueType == valueType &&
          other.value == value &&
          other.maxDiscountAmount == maxDiscountAmount &&
          other.minPurchase == minPurchase &&
          other.buyQty == buyQty &&
          other.getQty == getQty &&
          other.rewardType == rewardType &&
          other.rewardValue == rewardValue &&
          other.isMultiplied == isMultiplied &&
          other.buyScope == buyScope &&
          other.rewardScope == rewardScope &&
          _listEquality.equals(other.buyProductIds, buyProductIds) &&
          _listEquality.equals(other.buyCategoryIds, buyCategoryIds) &&
          _listEquality.equals(other.rewardProductIds, rewardProductIds) &&
          _listEquality.equals(other.rewardCategoryIds, rewardCategoryIds) &&
          const MapEquality<String, int>().equals(
            other.selectedRewardQtyMap,
            selectedRewardQtyMap,
          );

  @override
  int get hashCode => Object.hash(
    promotionId,
    promoType,
    priority,
    canCombine,
    valueType,
    value,
    maxDiscountAmount,
    minPurchase,
    buyQty,
    getQty,
    rewardType,
    rewardValue,
    isMultiplied,
    buyScope,
    rewardScope,
    _listEquality.hash(buyProductIds),
    _listEquality.hash(rewardProductIds),
    const MapEquality<String, int>().hash(selectedRewardQtyMap),
  );
}

/// Tax grouped by tax type, so a receipt can list each one separately.
class TaxBreakdown {
  const TaxBreakdown({
    required this.taxId,
    required this.taxName,
    required this.taxPercentage,
    required this.amount,
  });

  final int? taxId;
  final String taxName;
  final double taxPercentage;
  final double amount;
}

/// Everything the engine needs to price a transaction.
class TransactionCalculationInput {
  const TransactionCalculationInput({
    required this.cartItems,
    required this.paymentSettings,
    required this.paymentMethod,
    this.priceIncludeTax = false,
    this.discountInput,
    this.promotions = const [],
  });

  final List<CartItemData> cartItems;
  final PaymentSetting? paymentSettings;

  /// `CASH` triggers the rounding rules; anything else does not.
  final String paymentMethod;

  final bool priceIncludeTax;
  final DiscountInput? discountInput;
  final List<PromotionInput> promotions;

  bool get isCashPayment => paymentMethod.toUpperCase() == 'CASH';
}

/// The priced transaction.
///
/// [discountAmount] is what the manually-applied discount took off;
/// [promotionAmount] is what the automatically-evaluated promotions took off.
class TransactionCalculationResult {
  const TransactionCalculationResult({
    required this.subTotal,
    required this.serviceCharge,
    required this.tax,
    required this.rounding,
    required this.totalAmount,
    required this.transactionItems,
    this.discountAmount = 0,
    this.promotionAmount = 0,
    this.taxBreakdowns = const [],
    this.appliedPromotionIds = const [],
    this.perPromoAmounts = const {},
  });

  final double subTotal;
  final double discountAmount;
  final double promotionAmount;
  final double serviceCharge;
  final double tax;
  final double rounding;
  final double totalAmount;
  final List<RequestTransactionItem> transactionItems;
  final List<TaxBreakdown> taxBreakdowns;
  final List<int> appliedPromotionIds;

  /// Each applied promotion's own contribution, keyed by promotion id.
  final Map<int, double> perPromoAmounts;

  double get totalDeduction => discountAmount + promotionAmount;

  /// `grossAmount − totalDiscount − totalPromotion`. Tax is not deducted.
  double get netAmount => subTotal - totalDeduction;

  bool get hasDiscount => discountAmount > 0;
  bool get hasPromotion => promotionAmount > 0;
}

/// Per-line savings for the cart badges.
///
/// Display-only: this is not the figure sent to the backend.
class PerItemSavingsResult {
  const PerItemSavingsResult({required this.savings, required this.labels});

  const PerItemSavingsResult.empty() : savings = const {}, labels = const {};

  /// Cart key to the amount saved on that line.
  final Map<String, double> savings;

  /// Cart key to the badge label, e.g. `Diskon Member + Beli 1 Gratis 1`.
  final Map<String, String> labels;

  double savingFor(String cartKey) => savings[cartKey] ?? 0;

  String? labelFor(String cartKey) => labels[cartKey];

  bool get isEmpty => savings.isEmpty;
}
