import 'dart:math' as math;

import '../../../util/num_utils.dart';
import '../../calculator_models.dart';
import '../evaluation_context.dart';
import '../promotion_evaluator.dart';
import 'reward_strategy.dart';

/// A percentage off each reward unit.
///
/// The percentage applies to the unit's **net** price — after its share of the
/// manual discount — so the promotion is worth what the customer actually
/// saves. The total is rounded to whole rupiah, matching the backend.
class PercentageRewardStrategy extends RewardStrategy {
  const PercentageRewardStrategy();

  @override
  double calculateAmount(
    List<CartItemData> availableItems,
    int effectiveRewardQty,
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    final rewardValue = promo.rewardValue;
    if (rewardValue == null) return 0;

    double netPrice(CartItemData item) =>
        netPricePerUnit(item, ctx, roundAmountDiscount: true);

    var unitsLeft = effectiveRewardQty;
    var rewardSubtotal = 0.0;
    for (final item in sortedByStable(availableItems, netPrice)) {
      final units = math.min(unitsLeft, item.quantity);
      unitsLeft -= units;
      rewardSubtotal += netPrice(item) * units;
    }

    return jvmRound(rewardSubtotal * rewardValue / 100.0);
  }
}
