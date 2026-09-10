import 'dart:math' as math;

import '../../util/num_utils.dart';
import '../calculator_models.dart';
import 'evaluation_context.dart';
import 'promotion_evaluator.dart';

/// A discount on the subtotal of the items within the promotion's buy scope.
class DiscountByItemSubtotalEvaluator extends PromotionEvaluator {
  const DiscountByItemSubtotalEvaluator();

  @override
  double evaluate(PromotionInput promo, EvaluationContext ctx) {
    final value = promo.value;
    if (value == null) return 0;

    final eligible = filterItemsByScope(
      ctx.cartItems,
      promo.buyScope,
      promo.buyProductIds,
      promo.buyCategoryIds,
    );
    final cap = promo.maxDiscountAmount;

    switch (promo.valueType) {
      case DiscountInput.typePercentage:
        // Each line is rounded before summing, matching the backend. Summing
        // first and rounding once diverges by a rupiah.
        final raw = eligible.fold<double>(
          0,
          (sum, item) => sum + jvmRound(item.lineSubtotal * value / 100.0),
        );
        return cap != null && cap > 0 ? math.min(raw, cap) : raw;
      case DiscountInput.typeAmount:
        final eligibleSubTotal = eligible.fold<double>(
          0,
          (sum, i) => sum + i.lineSubtotal,
        );
        final raw = promo.isMultiplied
            ? eligible.fold<double>(0, (sum, i) => sum + value * i.quantity)
            : value;
        return math.min(raw, eligibleSubTotal);
      default:
        return 0;
    }
  }

  @override
  Map<String, double> perItemDeduction(
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    final promoAmount = evaluate(promo, ctx);
    if (promoAmount <= 0) return const {};

    final eligibleItems =
        filterItemsByScope(
              ctx.cartItems,
              promo.buyScope,
              promo.buyProductIds,
              promo.buyCategoryIds,
            )
            .where((i) => !ctx.freeItemCartKeys.contains(i.cartKey))
            .toList(growable: false);
    if (eligibleItems.isEmpty) return const {};

    // The tax base is the net subtotal: gross minus this line's share of the
    // manual discount.
    double netSubtotalOf(CartItemData item) {
      final discountInput = ctx.discountInput;
      final share = discountInput != null && ctx.totalDiscountAmt > 0
          ? computeItemDiscountAmt(
              item,
              discountInput,
              ctx.totalDiscountAmt,
              ctx.cartItems,
              freeItemCartKeys: ctx.freeItemCartKeys,
            )
          : 0.0;
      return atLeastZero(item.lineSubtotal - share);
    }

    final value = promo.value ?? 0;
    final deductions = <String, double>{};

    if (promo.valueType == DiscountInput.typePercentage && value > 0) {
      final cap = promo.maxDiscountAmount;
      final rawTotal = eligibleItems.fold<double>(
        0,
        (sum, item) => sum + jvmRound(netSubtotalOf(item) * value / 100.0),
      );
      for (final item in eligibleItems) {
        final rawItemAmt = jvmRound(netSubtotalOf(item) * value / 100.0);
        final itemAmt = cap != null && cap > 0 && rawTotal > cap && rawTotal > 0
            ? rawItemAmt * cap / rawTotal
            : rawItemAmt;
        if (itemAmt > 0) deductions[item.cartKey] = itemAmt;
      }
      return deductions;
    }

    final netEligibleSubtotal = eligibleItems.fold<double>(
      0,
      (sum, item) => sum + netSubtotalOf(item),
    );
    if (netEligibleSubtotal <= 0) return const {};

    for (final item in eligibleItems) {
      final itemAmt = promoAmount * netSubtotalOf(item) / netEligibleSubtotal;
      if (itemAmt > 0) deductions[item.cartKey] = itemAmt;
    }
    return deductions;
  }

  @override
  List<ItemPromoRole> itemRole(
    PromotionInput promo,
    CartItemData item,
    EvaluationContext ctx,
  ) {
    final isEligible = filterItemsByScope(
      [item],
      promo.buyScope,
      promo.buyProductIds,
      promo.buyCategoryIds,
    ).isNotEmpty;
    if (!isEligible) return const [];

    final itemAmt = perItemDeduction(promo, ctx)[item.cartKey];
    if (itemAmt == null) return const [];

    return [
      ItemPromoRole(
        promotionId: promo.promotionId,
        promoType: promo.promoType,
        role: ItemPromoRole.reward,
        amt: itemAmt,
      ),
    ];
  }
}
