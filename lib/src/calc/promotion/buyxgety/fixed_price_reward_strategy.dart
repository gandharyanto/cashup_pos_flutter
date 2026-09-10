import 'dart:math' as math;

import '../../../util/num_utils.dart';
import '../../calculator_models.dart';
import '../evaluation_context.dart';
import '../promotion_evaluator.dart';
import 'reward_strategy.dart';

/// Each reward unit is repriced to a fixed amount.
///
/// The saving is the gap between the unit's net price and that fixed price,
/// never negative — a unit already cheaper than the fixed price saves nothing
/// rather than costing the merchant.
class FixedPriceRewardStrategy extends RewardStrategy {
  const FixedPriceRewardStrategy();

  @override
  double calculateAmount(
    List<CartItemData> availableItems,
    int effectiveRewardQty,
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    final fixedPrice = promo.rewardValue;
    if (fixedPrice == null) return 0;

    double netPrice(CartItemData item) => netPricePerUnit(item, ctx);

    var unitsLeft = effectiveRewardQty;
    var total = 0.0;
    for (final item in sortedByStable(availableItems, netPrice)) {
      final units = math.min(unitsLeft, item.quantity);
      unitsLeft -= units;
      total += atLeastZero(netPrice(item) - fixedPrice) * units;
    }
    return total;
  }
}
