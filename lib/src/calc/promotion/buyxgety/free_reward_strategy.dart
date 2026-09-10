import 'dart:math' as math;

import '../../calculator_models.dart';
import '../evaluation_context.dart';
import '../promotion_evaluator.dart';
import 'reward_strategy.dart';

/// The reward units are free.
///
/// The promotion is worth the unit's **post-discount** price, not its gross
/// price. This was verified against a production rejection: combined with
/// `DISCOUNT_BY_ORDER`, the client sent `totalPromotionAmount` 77 623.00 while
/// the server computed 77 105.24, and the 517.76 gap was exactly the
/// discount's proportional share of the reward item's gross price.
class FreeRewardStrategy extends RewardStrategy {
  const FreeRewardStrategy();

  @override
  double calculateAmount(
    List<CartItemData> availableItems,
    int effectiveRewardQty,
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    var unitsLeft = effectiveRewardQty;
    var total = 0.0;
    // Cheapest first, by gross price: the server always gives away the
    // cheapest eligible units.
    for (final item in sortedByStable(availableItems, (i) => i.price)) {
      final units = math.min(unitsLeft, item.quantity);
      unitsLeft -= units;
      total += _postDiscountPriceForFreeUnit(item, ctx) * units;
    }
    return total;
  }

  double _postDiscountPriceForFreeUnit(
    CartItemData item,
    EvaluationContext ctx,
  ) {
    final discountInput = ctx.discountInput;

    if (discountInput == null) {
      // No structured discount to distribute — fall back to averaging the
      // line's recorded discount across its units.
      final discountTotal = ctx.discountPerCartKey[item.cartKey];
      if (discountTotal == null) return item.price;
      final originalQty = _originalQuantity(item, ctx);
      final perUnit = originalQty > 0 ? discountTotal / originalQty : 0.0;
      return item.price - perUnit;
    }

    switch (discountInput.valueType) {
      case DiscountInput.typePercentage:
        if (!_isEligible(item, discountInput)) return item.price;
        // The discount on a free unit is its proportional share of the
        // *rounded* total, not `round(price x rate)`. When another line's
        // percentage rounds down, the pool shrinks and every unit's share
        // shrinks with it — which is what the server distributes.
        final eligibleSubtotal = _eligibleEffectiveSubtotal(ctx, discountInput);
        final discountOnFreeUnit = eligibleSubtotal > 0
            ? ctx.totalDiscountAmt * item.price / eligibleSubtotal
            : 0.0;
        return item.price - discountOnFreeUnit;

      case DiscountInput.typeAmount:
        final originalQty = _originalQuantity(item, ctx);
        final discountTotal = ctx.discountPerCartKey[item.cartKey] ?? 0.0;
        final perUnit = originalQty > 0 ? discountTotal / originalQty : 0.0;
        return item.price - perUnit;

      default:
        return item.price;
    }
  }

  bool _isEligible(CartItemData item, DiscountInput discount) {
    switch (discount.scope) {
      case DiscountInput.scopeAll:
        return true;
      case DiscountInput.scopeProduct:
        return discount.eligibleProductIds.contains(item.productId);
      case DiscountInput.scopeCategory:
        return item.categoryIds.any(discount.eligibleCategoryIds.contains);
      default:
        return false;
    }
  }

  /// The subtotal the discount was spread across, at effective prices — so a
  /// product whose price comes partly from a variant behaves the same as an
  /// equivalent product priced entirely at base.
  double _eligibleEffectiveSubtotal(
    EvaluationContext ctx,
    DiscountInput discount,
  ) {
    switch (discount.scope) {
      case DiscountInput.scopeProduct:
        return ctx.originalCartItems
            .where((i) => discount.eligibleProductIds.contains(i.productId))
            .fold<double>(0, (sum, i) => sum + i.lineSubtotal);
      case DiscountInput.scopeCategory:
        return ctx.originalCartItems
            .where(
              (i) => i.categoryIds.any(discount.eligibleCategoryIds.contains),
            )
            .fold<double>(0, (sum, i) => sum + i.lineSubtotal);
      case DiscountInput.scopeAll:
      default:
        return ctx.subTotal;
    }
  }

  int _originalQuantity(CartItemData item, EvaluationContext ctx) {
    for (final original in ctx.originalCartItems) {
      if (original.cartKey == item.cartKey) return original.quantity;
    }
    return item.quantity;
  }
}
