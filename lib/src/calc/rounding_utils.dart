import '../util/num_utils.dart';

/// Total-amount rounding, ported from `RoundingUtils.kt`.
///
/// Applied to cash payments only — the payment settings' rounding rule does
/// not touch card or QRIS totals.
class RoundingUtils {
  RoundingUtils._();

  static const String floor = 'FLOOR';
  static const String ceiling = 'CEILING';
  static const String round = 'ROUND';
  static const String none = 'NONE';

  /// Rounds [amount] to a multiple of [target] using [type].
  ///
  /// A non-positive [target], `NONE`, or an unrecognised type all leave the
  /// amount untouched — the Kotlin original falls through the same way rather
  /// than throwing, because the value comes from merchant configuration.
  ///
  /// `ROUND` uses [jvmRound] rather than Dart's `num.round()` so ties break
  /// the same way the backend breaks them.
  static double applyRounding({
    required double amount,
    required int target,
    required String type,
  }) {
    if (target <= 0) return amount;
    switch (type.toUpperCase()) {
      case floor:
        return (amount / target).floorToDouble() * target;
      case ceiling:
        return (amount / target).ceilToDouble() * target;
      case round:
        return jvmRound(amount / target) * target;
      case none:
      default:
        return amount;
    }
  }

  /// The signed difference rounding introduced: positive when the total went
  /// up, negative when it went down.
  static double calculateRoundingAdjustment(
    double originalAmount,
    double roundedAmount,
  ) => roundedAmount - originalAmount;
}
