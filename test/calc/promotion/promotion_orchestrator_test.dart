import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/promotion/evaluation_context.dart';
import 'package:cashup_pos/src/calc/promotion/promotion_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `PromotionOrchestratorTest.kt`.
void main() {
  const orchestrator = PromotionOrchestrator();

  CartItemData item(
    String cartKey,
    double price, {
    int? productId,
    int qty = 1,
  }) => CartItemData(
    productId: productId ?? int.parse(cartKey),
    productName: 'P${productId ?? cartKey}',
    price: price,
    quantity: qty,
    cartKey: cartKey,
  );

  PromotionInput promoByOrder({
    int id = 1,
    required double value,
    bool canCombine = true,
    double minPurchase = 0,
  }) => PromotionInput(
    promotionId: id,
    promoType: 'DISCOUNT_BY_ORDER',
    priority: 1,
    canCombine: canCombine,
    valueType: 'AMOUNT',
    value: value,
    minPurchase: minPurchase,
  );

  PromotionInput promoBuyXGetY({
    required int id,
    required List<int> buyProductIds,
    required List<int> rewardProductIds,
    int priority = 1,
    bool isMultiplied = false,
  }) => PromotionInput(
    promotionId: id,
    promoType: 'BUY_X_GET_Y',
    priority: priority,
    canCombine: true,
    rewardType: 'FREE',
    buyQty: 1,
    getQty: 1,
    isMultiplied: isMultiplied,
    buyScope: 'PRODUCT',
    buyProductIds: buyProductIds,
    rewardScope: 'PRODUCT',
    rewardProductIds: rewardProductIds,
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

  test('evaluateAll singlePromo returnsCorrectAmount', () {
    final outcome = orchestrator.evaluateAll([
      promoByOrder(value: 10000),
    ], ctx(cart: [item('1', 50000)]));
    expect(outcome.totalAmount, closeTo(10000, 0.01));
    expect(outcome.appliedIds, contains(1));
  });

  test('evaluateAll canCombineFalse stopsAfterFirstApplied', () {
    final outcome = orchestrator.evaluateAll([
      promoByOrder(id: 1, value: 5000, canCombine: false),
      promoByOrder(id: 2, value: 3000),
    ], ctx(cart: [item('1', 50000)]));
    expect(outcome.appliedIds, contains(1));
    expect(outcome.appliedIds, isNot(contains(2)));
  });

  test('evaluateAll belowMinPurchase promoNotApplied', () {
    final outcome = orchestrator.evaluateAll([
      promoByOrder(value: 1000, minPurchase: 10000),
    ], ctx(cart: [item('1', 5000)]));
    expect(outcome.totalAmount, closeTo(0, 0.01));
    expect(outcome.appliedIds, isEmpty);
  });

  test('evaluateAll buyXGetY claimedUnitsPreventDoubleReward', () {
    final buyer = item('1', 20000, productId: 10);
    final reward = item('2', 5000, productId: 20);
    final outcome = orchestrator.evaluateAll([
      promoBuyXGetY(
        id: 1,
        buyProductIds: const [10],
        rewardProductIds: const [20],
      ),
      promoBuyXGetY(
        id: 2,
        buyProductIds: const [10],
        rewardProductIds: const [20],
      ),
    ], ctx(cart: [buyer, reward]));
    expect(outcome.appliedIds, contains(1));
    expect(
      outcome.appliedIds,
      isNot(contains(2)),
      reason: 'no unclaimed reward units left',
    );
  });

  test('evaluateAll freeBuyXGetY evaluatedBeforeNonFree', () {
    final buyer = item('1', 20000, productId: 10);
    final reward = item('2', 5000, productId: 20);
    final outcome = orchestrator.evaluateAll([
      promoBuyXGetY(
        id: 1,
        buyProductIds: const [10],
        rewardProductIds: const [20],
        priority: 5,
      ),
    ], ctx(cart: [buyer, reward]));
    expect(outcome.appliedIds, contains(1));
  });

  test('computeAllPerItemDeductions aggregatesAcrossAppliedPromos', () {
    final item1 = item('1', 60000);
    final item2 = item('2', 40000);
    final deductions = orchestrator.computeAllPerItemDeductions(
      [promoByOrder(value: 10000)],
      const [1],
      ctx(cart: [item1, item2]),
    );
    expect(deductions['1'] ?? 0, closeTo(6000, 0.01));
    expect(deductions['2'] ?? 0, closeTo(4000, 0.01));
  });

  test('computeAllItemRoles returnsRolesFromAppliedPromos', () {
    final buyer = item('1', 20000, productId: 10);
    final reward = item('2', 5000, productId: 20);
    final roles = orchestrator.computeAllItemRoles(
      buyer,
      [
        promoBuyXGetY(
          id: 1,
          buyProductIds: const [10],
          rewardProductIds: const [20],
        ),
      ],
      const [1],
      ctx(cart: [buyer, reward]),
    );
    expect(roles.any((r) => r.role == 'QUALIFIER'), isTrue);
  });

  test('computeAllItemRoles emptyWhenNoAppliedPromos', () {
    final line = item('1', 20000);
    expect(
      orchestrator.computeAllItemRoles(
        line,
        [promoByOrder(value: 5000)],
        const [],
        ctx(cart: [line]),
      ),
      isEmpty,
    );
  });

  test(
    'evaluateAll multipliedOverlap claimsAllRewardCycles blockingSecondPromo',
    () {
      // Product P (pid=30), qty=4. BUY 1 GET 1 isMultiplied on the same product
      // gives 2 cycles, so 2 reward units are claimed and an identical second
      // promotion has nothing left to reward.
      final p = item('1', 10000, productId: 30, qty: 4);
      final outcome = orchestrator.evaluateAll([
        promoBuyXGetY(
          id: 1,
          buyProductIds: const [30],
          rewardProductIds: const [30],
          isMultiplied: true,
        ),
        promoBuyXGetY(
          id: 2,
          buyProductIds: const [30],
          rewardProductIds: const [30],
          isMultiplied: true,
        ),
      ], ctx(cart: [p]));
      expect(outcome.appliedIds, contains(1));
      expect(
        outcome.appliedIds,
        isNot(contains(2)),
        reason:
            'second promo must be blocked after the first claims all cycles',
      );
    },
  );

  test('evaluateAll freeAndPercentageBxgy sameQualifier wideOverlappingRewardCatalog bothApply', () {
    // Production case: promo A (FREE) and promo B (PERCENTAGE) both need one
    // unit of the same qualifier and share the reward catalogue [20, 21]. With
    // two qualifier units in the cart, each promotion claims its own.
    //
    // The bug this pins: qualifier consumption used to be recorded once per
    // overlapping reward product rather than once per promotion application, so
    // a wide reward catalogue double-counted the FREE promo's consumption and
    // wrongly blocked promo B.
    final buyer = item('1', 5000, productId: 10, qty: 2);
    final cheapReward = item('2', 3000, productId: 20);
    final pricierReward = item('3', 4000, productId: 21);

    const percentagePromo = PromotionInput(
      promotionId: 2,
      promoType: 'BUY_X_GET_Y',
      priority: 1,
      canCombine: true,
      rewardType: 'PERCENTAGE',
      rewardValue: 10,
      buyQty: 1,
      getQty: 1,
      buyScope: 'PRODUCT',
      buyProductIds: [10],
      rewardScope: 'PRODUCT',
      rewardProductIds: [20, 21],
    );

    final outcome = orchestrator.evaluateAll([
      promoBuyXGetY(
        id: 1,
        buyProductIds: const [10],
        rewardProductIds: const [20, 21],
      ),
      percentagePromo,
    ], ctx(cart: [buyer, cheapReward, pricierReward]));

    expect(
      outcome.appliedIds,
      contains(1),
      reason: 'FREE promo must apply (cheapest reward 20 becomes free)',
    );
    expect(
      outcome.appliedIds,
      contains(2),
      reason: 'PERCENTAGE must also apply against reward 21 using the 2nd qualifier',
    );
    // FREE claims reward 20 (3000); PERCENTAGE takes 10% of reward 21 (400).
    expect(outcome.totalAmount, closeTo(3400, 0.01));
  });

  test('evaluateAll reports each promotion contribution separately', () {
    final outcome = orchestrator.evaluateAll([
      promoByOrder(id: 1, value: 5000),
      promoByOrder(id: 2, value: 3000),
    ], ctx(cart: [item('1', 50000)]));
    expect(outcome.perPromoAmounts[1], closeTo(5000, 0.01));
    expect(outcome.perPromoAmounts[2], closeTo(3000, 0.01));
    expect(outcome.totalAmount, closeTo(8000, 0.01));
  });

  test('evaluateAll returns nothing for an empty promotion list', () {
    final outcome = orchestrator.evaluateAll(const [], ctx());
    expect(outcome.totalAmount, 0);
    expect(outcome.appliedIds, isEmpty);
    expect(outcome.perPromoAmounts, isEmpty);
  });
}
