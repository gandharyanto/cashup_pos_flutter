import '../calculator_models.dart';

/// The immutable snapshot every promotion evaluator reads.
///
/// Built once by the calculator before the orchestrator loop. Only
/// [cartItems] and [subTotal] change between iterations, as the orchestrator
/// subtracts units already claimed by earlier promotions.
class EvaluationContext {
  const EvaluationContext({
    required this.cartItems,
    required this.originalCartItems,
    required this.discountInput,
    required this.totalDiscountAmt,
    required this.subTotal,
    required this.freeItemCartKeys,
    required this.freeQtyByCartKey,
    this.discountPerCartKey = const {},
  });

  /// The cart as this promotion sees it, with claimed units already removed.
  final List<CartItemData> cartItems;

  /// The unmodified cart.
  ///
  /// Used as the denominator in discount-share calculations so that removing
  /// claimed units does not inflate the share carried by the units that
  /// remain.
  final List<CartItemData> originalCartItems;

  final DiscountInput? discountInput;
  final double totalDiscountAmt;
  final double subTotal;

  /// Lines where *every* unit is free from a `BUY_X_GET_Y` FREE reward.
  final Set<String> freeItemCartKeys;

  /// Cart key to the number of units that are free. A partially free line
  /// appears here but not in [freeItemCartKeys].
  final Map<String, int> freeQtyByCartKey;

  /// Cart key to that line's discount amount at full quantity.
  ///
  /// Seeded by the calculator so `FreeRewardStrategy` can price a free unit
  /// after discount without recomputing the whole distribution.
  final Map<String, double> discountPerCartKey;

  EvaluationContext copyWith({
    List<CartItemData>? cartItems,
    double? subTotal,
  }) => EvaluationContext(
    cartItems: cartItems ?? this.cartItems,
    originalCartItems: originalCartItems,
    discountInput: discountInput,
    totalDiscountAmt: totalDiscountAmt,
    subTotal: subTotal ?? this.subTotal,
    freeItemCartKeys: freeItemCartKeys,
    freeQtyByCartKey: freeQtyByCartKey,
    discountPerCartKey: discountPerCartKey,
  );
}
