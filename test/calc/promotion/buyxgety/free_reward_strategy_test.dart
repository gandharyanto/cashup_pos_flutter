import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/promotion/buyxgety/free_reward_strategy.dart';
import 'package:cashup_pos/src/calc/promotion/evaluation_context.dart';
import 'package:cashup_pos/src/util/num_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `FreeRewardStrategyTest.kt`.
void main() {
  const strategy = FreeRewardStrategy();

  CartItemData item(int id, double price, {int qty = 1}) => CartItemData(
    productId: id,
    productName: 'P$id',
    price: price,
    quantity: qty,
    cartKey: '$id',
  );

  const promo = PromotionInput(
    promotionId: 1,
    promoType: 'BUY_X_GET_Y',
    priority: 1,
    canCombine: false,
    rewardType: 'FREE',
    buyQty: 1,
    getQty: 1,
  );

  EvaluationContext emptyCtx({
    Map<String, double> discountPerCartKey = const {},
  }) => EvaluationContext(
    cartItems: const [],
    originalCartItems: const [],
    discountInput: null,
    totalDiscountAmt: 0,
    subTotal: 0,
    freeItemCartKeys: const {},
    freeQtyByCartKey: const {},
    discountPerCartKey: discountPerCartKey,
  );

  test('calculateAmount selectsCheapestItem', () {
    expect(
      strategy.calculateAmount(
        [item(1, 20000), item(2, 5000)],
        1,
        promo,
        emptyCtx(),
      ),
      closeTo(5000, 0.01),
    );
  });

  test('calculateAmount uses post-discount price for PARTIALLY-free unit', () {
    // item price=10000, qty=2 -> one unit free (partial), one paid discounted.
    // subTotal=20000, totalDiscountAmt=round(20000x20%)=4000
    // discountOnFreeUnit = 4000 x 10000/20000 = 2000 -> postDiscount = 8000
    final line = item(1, 10000, qty: 2);
    const discount = DiscountInput(valueType: 'PERCENTAGE', value: 20);
    final ctx = EvaluationContext(
      cartItems: [line],
      originalCartItems: [line],
      discountInput: discount,
      totalDiscountAmt: 4000,
      subTotal: 20000,
      freeItemCartKeys: const {},
      freeQtyByCartKey: const {},
      discountPerCartKey: const {'1': 4000},
    );
    expect(
      strategy.calculateAmount([line], 1, promo, ctx),
      closeTo(8000, 0.01),
    );
  });

  test(
    'calculateAmount uses post-discount price when discountPerCartKey provided',
    () {
      // item price=14000, qty=2, discount=5600 (14000x2x20%)
      // discountPerUnit = 5600/2 = 2800, postDiscountPrice = 14000-2800 = 11200
      // FREE 1 unit -> saving = 11200
      final line = item(1, 14000, qty: 2);
      expect(
        strategy.calculateAmount(
          [line],
          1,
          promo,
          emptyCtx(discountPerCartKey: const {'1': 5600}),
        ),
        closeTo(11200, 0.01),
      );
    },
  );

  test('calculateAmount claimsExactQty whenItemHasMultipleUnits', () {
    expect(
      strategy.calculateAmount([item(1, 5000, qty: 3)], 2, promo, emptyCtx()),
      closeTo(10000, 0.01),
    );
  });

  test('calculateAmount uses post-discount price for fully-free item with percentage discount', () {
    // PA2: price=22000 (effectivePrice), basePrice=20000, qty=1, all units free.
    // PERCENTAGE 20% ALL: prelim discount = 14600 (includes PA2's 4400).
    const pa2 = CartItemData(
      productId: 2,
      productName: 'PA2',
      price: 22000,
      basePrice: 20000,
      quantity: 1,
      cartKey: '2',
    );
    const kwt = CartItemData(
      productId: 1,
      productName: 'KWT',
      price: 51000,
      basePrice: 49000,
      quantity: 1,
      cartKey: '1',
    );
    const discount = DiscountInput(valueType: 'PERCENTAGE', value: 20);
    const ctx = EvaluationContext(
      cartItems: [pa2, kwt],
      originalCartItems: [pa2, kwt],
      discountInput: discount,
      // prelim: round(22000x0.2)+round(51000x0.2) = 4400+10200 = 14600
      totalDiscountAmt: 14600,
      subTotal: 73000,
      freeItemCartKeys: {},
      freeQtyByCartKey: {},
    );

    expect(
      strategy.calculateAmount(const [pa2], 1, promo, ctx),
      closeTo(17600, 0.01),
    );
  });

  test('calculateAmount uses effectivePrice when basePrice is zero', () {
    // Price-adjustable product: basePrice=0, effectivePrice=2000 (variant adds).
    const pa2 = CartItemData(
      productId: 2,
      productName: 'PA2',
      price: 2000,
      basePrice: 0,
      quantity: 1,
      cartKey: '2',
    );
    const other = CartItemData(
      productId: 1,
      productName: 'Other',
      price: 49000,
      quantity: 1,
      cartKey: '1',
    );
    const discount = DiscountInput(valueType: 'PERCENTAGE', value: 20);
    final totalDiscountAmt = jvmRound(49000 * 0.20) + jvmRound(2000 * 0.20);
    final ctx = EvaluationContext(
      cartItems: const [pa2, other],
      originalCartItems: const [pa2, other],
      discountInput: discount,
      totalDiscountAmt: totalDiscountAmt,
      subTotal: 51000,
      freeItemCartKeys: const {},
      freeQtyByCartKey: const {},
    );

    expect(
      strategy.calculateAmount(const [pa2], 1, promo, ctx),
      closeTo(1600, 0.01),
    );
  });

  test('calculateAmount uses proportional discount for PERCENTAGE ALL when rounding loss shifts shares', () {
    // buah (11111x2) has a fractional discount (4444.4 -> 4444, losing 0.4), so
    // the rounded totalDiscountAmt is below a strict 20% of subTotal. The server
    // distributes the rounded total proportionally, which leaves the free unit
    // with slightly less discount -- and a slightly higher post-discount price
    // than Math.round(price x rate) would give.
    const buah = CartItemData(
      productId: 1,
      productName: 'buah',
      price: 11111,
      quantity: 2,
      cartKey: '1',
    );
    const pa2 = CartItemData(
      productId: 2,
      productName: 'PA2',
      price: 150000,
      quantity: 2,
      cartKey: '2',
    );
    const subTotal = 11111.0 * 2 + 150000.0 * 2; // 322222
    final totalDiscountAmt = jvmRound(22222 * 0.20) + jvmRound(300000 * 0.20);
    const discount = DiscountInput(valueType: 'PERCENTAGE', value: 20);
    final ctx = EvaluationContext(
      cartItems: const [buah, pa2],
      originalCartItems: const [buah, pa2],
      discountInput: discount,
      totalDiscountAmt: totalDiscountAmt,
      subTotal: subTotal,
      freeItemCartKeys: const {},
      freeQtyByCartKey: const {},
    );

    final result = strategy.calculateAmount(
      [pa2.copyWith(quantity: 1)],
      1,
      promo,
      ctx,
    );

    final expected = 150000.0 - totalDiscountAmt * 150000.0 / subTotal;
    expect(result, closeTo(expected, 0.001));
    expect(
      (result - 120000.0).abs(),
      greaterThan(0.1),
      reason: 'must differ from the old Math.round formula (120000)',
    );
  });
}
