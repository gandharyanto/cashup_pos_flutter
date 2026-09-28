import '../calc/calculator_models.dart';
import '../models/discount_item.dart';
import '../models/promotion_item.dart';
import '../state/cart_controller.dart';

/// Converts an API discount into the calculator's input shape.
DiscountInput toDiscountInput(DiscountItem item) => DiscountInput(
  discountId: item.id,
  name: item.name,
  valueType: item.valueType,
  value: item.value,
  maxDiscountAmount: item.maxDiscountAmount,
  minPurchase: item.minPurchase,
  scope: item.scope,
  eligibleProductIds: item.targetProductIds,
  eligibleCategoryIds: item.categoryIds,
);

/// Converts active API promotions into calculator inputs.
///
/// `DISCOUNT_BY_ORDER` stores its value under the reward-prefixed API fields,
/// so those fields are the fallback when the ordinary value fields are null.
List<PromotionInput> toPromotionInputs(
  List<PromotionItem> items, {
  Map<int, Map<String, int>> selectedRewards = const {},
}) => items
    .map(
      (item) => PromotionInput(
        promotionId: item.id,
        name: item.name,
        promoType: item.promoType,
        priority: item.priority,
        canCombine: item.canCombine,
        valueType: item.valueType ?? item.rewardValueType,
        value: item.value ?? item.rewardDiscountValue,
        maxDiscountAmount: item.maxDiscountAmount,
        minPurchase: item.minPurchase,
        buyQty: item.buyQty,
        getQty: item.rewardQty,
        rewardType: item.rewardType,
        rewardValue: item.rewardValue,
        isMultiplied: item.isMultiplied,
        buyScope: _scope(item.buyProductIds, item.buyCategoryIds),
        buyProductIds: item.buyProductIds,
        buyCategoryIds: item.buyCategoryIds,
        rewardScope: _scope(item.rewardProductIds, item.rewardCategoryIds),
        rewardProductIds: item.rewardProductIds,
        rewardCategoryIds: item.rewardCategoryIds,
        selectedRewardQtyMap: selectedRewards[item.id] ?? const {},
        activeDays: item.schedule?.activeDays ?? const [],
        activeStartTime: item.schedule?.startTime,
        activeEndTime: item.schedule?.endTime,
      ),
    )
    .toList(growable: false);

String _scope(List<int> productIds, List<int> categoryIds) {
  if (categoryIds.isNotEmpty) return PromotionInput.scopeCategory;
  if (productIds.isNotEmpty) return PromotionInput.scopeProduct;
  return PromotionInput.scopeAll;
}

/// Converts a configured cart line without dropping calculator metadata.
CartItemData toCartItemData(PosCartLine line) {
  final product = line.product;
  final basePrice = line.customBasePrice ?? product.basePrice;
  return CartItemData(
    productId: product.id,
    productName: product.name,
    price: line.effectivePrice,
    basePrice: basePrice,
    quantity: line.quantity,
    taxAmountPerUnit: product.tax?.taxAmount ?? 0,
    isTaxable: product.isTaxable,
    taxId: product.tax?.taxId,
    taxName: product.tax?.taxName,
    taxPercentage: product.tax?.taxPercentage,
    variantId: line.selectedVariants.lastOrNull?.id,
    selectedVariants: line.selectedVariants,
    selectedModifiers: line.selectedModifiers,
    categoryIds: product.categoryIds,
    cartKey: line.cartKey,
    isPriceAdjustable: product.isPriceAdjustable,
    isPriceOverride:
        line.customBasePrice != null &&
        line.customBasePrice != product.basePrice,
  );
}
