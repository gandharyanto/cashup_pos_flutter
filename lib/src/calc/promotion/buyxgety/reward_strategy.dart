import '../../calculator_models.dart';
import '../evaluation_context.dart';

/// How one `BUY_X_GET_Y` reward type prices its reward units.
///
/// One implementation per reward type, kept in separate files on purpose: in
/// the Kotlin original these four shared helpers, and a fix to FREE
/// repeatedly shifted PERCENTAGE and AMOUNT. Do not merge them.
abstract class RewardStrategy {
  const RewardStrategy();

  /// The amount this promotion takes off, given the reward candidates and how
  /// many units the promotion actually delivers.
  ///
  /// [availableItems] already has qualifier-reserved units removed.
  double calculateAmount(
    List<CartItemData> availableItems,
    int effectiveRewardQty,
    PromotionInput promo,
    EvaluationContext ctx,
  );
}
