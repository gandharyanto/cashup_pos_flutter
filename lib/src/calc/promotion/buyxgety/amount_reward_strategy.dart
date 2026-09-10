import 'dart:math' as math;

import '../../calculator_models.dart';
import '../evaluation_context.dart';
import '../promotion_evaluator.dart';
import 'reward_strategy.dart';

/// A flat amount off each reward unit, capped at what the unit costs.
///
/// The cap applies **per unit**, not to the total: two reward units at 19 000
/// and 22 000 with a 20 000 reward give 19 000 + 20 000, not 40 000.
class AmountRewardStrategy extends RewardStrategy {
  const AmountRewardStrategy();

  @override
  double calculateAmount(
    List<CartItemData> availableItems,
    int effectiveRewardQty,
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    final rewardValue = promo.rewardValue;
    if (rewardValue == null) return 0;

    double netPrice(CartItemData item) => netPricePerUnit(item, ctx);

    var unitsLeft = effectiveRewardQty;
    var total = 0.0;
    for (final item in sortedByStable(availableItems, netPrice)) {
      final units = math.min(unitsLeft, item.quantity);
      unitsLeft -= units;
      total += math.min(rewardValue, netPrice(item)) * units;
    }
    return total;
  }
}
