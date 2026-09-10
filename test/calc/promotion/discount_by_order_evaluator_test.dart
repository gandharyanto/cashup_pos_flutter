import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/promotion/discount_by_order_evaluator.dart';
import 'package:cashup_pos/src/calc/promotion/evaluation_context.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `DiscountByOrderEvaluatorTest.kt`. Test names and numbers are
/// kept as they are — several came from production mismatches.
void main() {
  const evaluator = DiscountByOrderEvaluator();

  CartItemData item(String cartKey, double price) => CartItemData(
    productId: int.parse(cartKey),
    productName: 'P$cartKey',
    price: price,
    quantity: 1,
    cartKey: cartKey,
  );

  PromotionInput promo({
    required String valueType,
    required double value,
    double? maxCap,
  }) => PromotionInput(
    promotionId: 1,
    promoType: 'DISCOUNT_BY_ORDER',
    priority: 1,
    canCombine: false,
    valueType: valueType,
    value: value,
    maxDiscountAmount: maxCap,
  );

  EvaluationContext ctx({
    double subTotal = 0,
    double discountAmt = 0,
    List<CartItemData> cart = const [],
  }) => EvaluationContext(
    cartItems: cart,
    originalCartItems: cart,
    discountInput: null,
    totalDiscountAmt: discountAmt,
    subTotal: subTotal,
    freeItemCartKeys: const {},
    freeQtyByCartKey: const {},
  );

  test('evaluate percentageType onNetSubtotal', () {
    // netSubTotal = 100000-10000 = 90000; 20% = 18000
    expect(
      evaluator.evaluate(
        promo(valueType: 'PERCENTAGE', value: 20),
        ctx(subTotal: 100000, discountAmt: 10000),
      ),
      closeTo(18000, 0.01),
    );
  });

  test('evaluate amountType returnsValueDirectly', () {
    expect(
      evaluator.evaluate(
        promo(valueType: 'AMOUNT', value: 15000),
        ctx(subTotal: 100000),
      ),
      closeTo(15000, 0.01),
    );
  });

  test('evaluate percentageWithCap respectsCap', () {
    expect(
      evaluator.evaluate(
        promo(valueType: 'PERCENTAGE', value: 50, maxCap: 30000),
        ctx(subTotal: 200000),
      ),
      closeTo(30000, 0.01),
    );
  });

  test('perItemDeduction distributesProportionally', () {
    final item1 = item('1', 60000);
    final item2 = item('2', 40000);
    final deductions = evaluator.perItemDeduction(
      promo(valueType: 'AMOUNT', value: 10000),
      ctx(subTotal: 100000, cart: [item1, item2]),
    );
    expect(deductions['1'] ?? 0, closeTo(6000, 0.01));
    expect(deductions['2'] ?? 0, closeTo(4000, 0.01));
  });

  test('evaluate amountType cappedAtNetSubtotal', () {
    // value 60000 exceeds netSubTotal (50000-10000=40000) -> capped at 40000
    expect(
      evaluator.evaluate(
        promo(valueType: 'AMOUNT', value: 60000),
        ctx(subTotal: 50000, discountAmt: 10000),
      ),
      closeTo(40000, 0.01),
    );
  });

  test('itemRole alwaysReturnsReward', () {
    final line = item('1', 50000);
    final roles = evaluator.itemRole(
      promo(valueType: 'AMOUNT', value: 5000),
      line,
      ctx(subTotal: 50000, cart: [line]),
    );
    expect(roles.length, 1);
    expect(roles.first.role, 'REWARD');
  });

  test('perItemDeduction roundsToInteger forTaxBaseAlignment', () {
    // Reproduces the BE log mismatch: server tax=660.00, client tax=659.97.
    //
    // DISCOUNT_BY_ORDER PERCENTAGE 10% on item price=7333:
    //   raw promo = 7333 x 10% = 733.3
    //   Math.round(733.3) = 733  <- what BE uses for netAmount
    //   taxBase = 7333 - 733 = 6600 -> tax = 660.00
    final line = item('1', 7333);
    final deductions = evaluator.perItemDeduction(
      promo(valueType: 'PERCENTAGE', value: 10),
      ctx(subTotal: 7333, cart: [line]),
    );
    expect(
      deductions['1'] ?? 0,
      closeTo(733, 0.001),
      reason: 'deduction must be rounded to integer',
    );
  });

  test('evaluate percentageOnFractionalAmount returnsRaw', () {
    // evaluate() itself is NOT rounded -- rounding only in
    // perItemDeduction/itemRole.
    expect(
      evaluator.evaluate(
        promo(valueType: 'PERCENTAGE', value: 10),
        ctx(subTotal: 7333),
      ),
      closeTo(733.3, 0.001),
      reason: 'evaluate returns raw unrounded',
    );
  });
}
