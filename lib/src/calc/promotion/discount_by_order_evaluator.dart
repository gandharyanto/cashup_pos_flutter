import 'dart:math' as math;

import '../../util/num_utils.dart';
import '../calculator_models.dart';
import 'evaluation_context.dart';
import 'promotion_evaluator.dart';

/// A flat or percentage discount on the whole order.
///
/// The percentage applies to the *net* subtotal — after the manual discount,
/// not before it.
class DiscountByOrderEvaluator extends PromotionEvaluator {
  const DiscountByOrderEvaluator();

  @override
  double evaluate(PromotionInput promo, EvaluationContext ctx) {
    final value = promo.value;
    if (value == null) return 0;

    final cap = promo.maxDiscountAmount;
    final netSubTotal = atLeastZero(ctx.subTotal - ctx.totalDiscountAmt);

    switch (promo.valueType) {
      case DiscountInput.typePercentage:
        final raw = netSubTotal * value / 100.0;
        return cap != null && cap > 0 ? math.min(raw, cap) : raw;
      case DiscountInput.typeAmount:
        return math.min(value, netSubTotal);
      default:
        return 0;
    }
  }

  @override
  Map<String, double> perItemDeduction(
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    final effectiveAmt = _effectiveAmt(promo, ctx);
    if (effectiveAmt <= 0) return const {};

    final paidItems = ctx.cartItems
        .where((i) => !ctx.freeItemCartKeys.contains(i.cartKey))
        .toList(growable: false);
    final paidSubTotal = paidItems.fold<double>(
      0,
      (sum, i) => sum + i.lineSubtotal,
    );
    if (paidSubTotal <= 0) return const {};

    final deductions = <String, double>{};
    for (final item in paidItems) {
      final amount = effectiveAmt * item.lineSubtotal / paidSubTotal;
      if (amount > 0) deductions[item.cartKey] = amount;
    }
    return deductions;
  }

  @override
  List<ItemPromoRole> itemRole(
    PromotionInput promo,
    CartItemData item,
    EvaluationContext ctx,
  ) {
    final amount = perItemDeduction(promo, ctx)[item.cartKey];
    if (amount == null || amount <= 0) return const [];
    return [
      ItemPromoRole(
        promotionId: promo.promotionId,
        promoType: promo.promoType,
        role: ItemPromoRole.reward,
        amt: amount,
      ),
    ];
  }

  /// The amount the backend actually credits.
  ///
  /// `DISCOUNT_BY_ORDER` is the only promotion type whose contribution the
  /// backend rounds to the nearest rupiah before computing `netAmount`.
  /// Mirroring it here is what keeps the client's tax base aligned: a 10%
  /// promotion on a 7 333 line must deduct 733, not 733.3, or the tax comes
  /// out at 659.97 against the server's 660.00.
  double _effectiveAmt(PromotionInput promo, EvaluationContext ctx) => jvmRound(
    math.min(
      evaluate(promo, ctx),
      atLeastZero(ctx.subTotal - ctx.totalDiscountAmt),
    ),
  );
}
