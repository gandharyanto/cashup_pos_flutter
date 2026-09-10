import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/promotion/discount_by_item_subtotal_evaluator.dart';
import 'package:cashup_pos/src/calc/promotion/evaluation_context.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `DiscountByItemSubtotalEvaluatorTest.kt`.
void main() {
  const evaluator = DiscountByItemSubtotalEvaluator();

  CartItemData item(String cartKey, double price, {int productId = 1}) =>
      CartItemData(
        productId: productId,
        productName: 'P$productId',
        price: price,
        quantity: 1,
        cartKey: cartKey,
      );

  PromotionInput promo({
    required String valueType,
    required double value,
    List<int> buyProductIds = const [],
    double? maxCap,
    bool isMultiplied = false,
  }) => PromotionInput(
    promotionId: 1,
    promoType: 'DISCOUNT_BY_ITEM_SUBTOTAL',
    priority: 1,
    canCombine: false,
    valueType: valueType,
    value: value,
    maxDiscountAmount: maxCap,
    isMultiplied: isMultiplied,
    buyScope: 'PRODUCT',
    buyProductIds: buyProductIds,
  );

  EvaluationContext ctx({List<CartItemData> cart = const []}) =>
      EvaluationContext(
        cartItems: cart,
        originalCartItems: cart,
        discountInput: null,
        totalDiscountAmt: 0,
        subTotal: cart.fold(0, (sum, i) => sum + i.lineSubtotal),
        freeItemCartKeys: const {},
        freeQtyByCartKey: const {},
      );

  test('evaluate percentageOnEligibleItems roundsPerItem', () {
    final line = item('1', 10000, productId: 5);
    expect(
      evaluator.evaluate(
        promo(valueType: 'PERCENTAGE', value: 10, buyProductIds: const [5]),
        ctx(cart: [line]),
      ),
      closeTo(1000, 0.01),
    );
  });

  test('evaluate amountType cappedAtEligibleSubtotal', () {
    final line = item('1', 5000, productId: 5);
    expect(
      evaluator.evaluate(
        promo(valueType: 'AMOUNT', value: 9999, buyProductIds: const [5]),
        ctx(cart: [line]),
      ),
      closeTo(5000, 0.01),
    );
  });

  test('evaluate ineligibleItem returnsZero', () {
    final line = item('1', 10000, productId: 99);
    expect(
      evaluator.evaluate(
        promo(valueType: 'PERCENTAGE', value: 10, buyProductIds: const [5]),
        ctx(cart: [line]),
      ),
      closeTo(0, 0.01),
    );
  });

  test('perItemDeduction onlyEligibleItemsGetDeduction', () {
    final eligible = item('1', 10000, productId: 5);
    final ineligible = item('2', 10000, productId: 99);
    final deductions = evaluator.perItemDeduction(
      promo(valueType: 'AMOUNT', value: 2000, buyProductIds: const [5]),
      ctx(cart: [eligible, ineligible]),
    );
    expect(deductions['1'] ?? 0, closeTo(2000, 0.01));
    expect(deductions.containsKey('2'), isFalse);
  });

  test('itemRole eligibleItemGetsReward', () {
    final line = item('1', 10000, productId: 5);
    final roles = evaluator.itemRole(
      promo(valueType: 'AMOUNT', value: 2000, buyProductIds: const [5]),
      line,
      ctx(cart: [line]),
    );
    expect(roles.length, 1);
    expect(roles.first.role, 'REWARD');
  });

  test('itemRole ineligibleItemReturnsEmpty', () {
    final line = item('1', 10000, productId: 99);
    expect(
      evaluator.itemRole(
        promo(valueType: 'AMOUNT', value: 2000, buyProductIds: const [5]),
        line,
        ctx(cart: [line]),
      ),
      isEmpty,
    );
  });

  test('evaluate amountMultiplied multipliesPerQty', () {
    const line = CartItemData(
      productId: 5,
      productName: 'P5',
      price: 10000,
      quantity: 3,
      cartKey: '1',
    );
    // 2000 * 3 = 6000, capped at eligibleSubtotal 30000 -> 6000
    expect(
      evaluator.evaluate(
        promo(
          valueType: 'AMOUNT',
          value: 2000,
          buyProductIds: const [5],
          isMultiplied: true,
        ),
        ctx(cart: const [line]),
      ),
      closeTo(6000, 0.01),
    );
  });

  test('evaluate percentageWithCap respectsCap', () {
    final line = item('1', 100000, productId: 5);
    // 50% of 100000 = 50000, capped at 30000
    expect(
      evaluator.evaluate(
        promo(
          valueType: 'PERCENTAGE',
          value: 50,
          buyProductIds: const [5],
          maxCap: 30000,
        ),
        ctx(cart: [line]),
      ),
      closeTo(30000, 0.01),
    );
  });
}
