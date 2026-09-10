import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/promotion/buyxgety/buy_x_get_y_evaluator.dart';
import 'package:cashup_pos/src/calc/promotion/evaluation_context.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `BuyXGetYEvaluatorTest.kt`.
void main() {
  const evaluator = BuyXGetYEvaluator();

  CartItemData item(int id, double price, {int qty = 1}) => CartItemData(
    productId: id,
    productName: 'P$id',
    price: price,
    quantity: qty,
    cartKey: '$id',
  );

  PromotionInput promo({
    List<int> buyProductIds = const [],
    List<int> rewardProductIds = const [],
    required String rewardType,
    double? rewardValue,
    int buyQty = 1,
    int getQty = 1,
  }) => PromotionInput(
    promotionId: 1,
    promoType: 'BUY_X_GET_Y',
    priority: 1,
    canCombine: false,
    rewardType: rewardType,
    rewardValue: rewardValue,
    buyQty: buyQty,
    getQty: getQty,
    buyScope: 'PRODUCT',
    buyProductIds: buyProductIds,
    rewardScope: 'PRODUCT',
    rewardProductIds: rewardProductIds,
  );

  EvaluationContext ctx(List<CartItemData> cart) => EvaluationContext(
    cartItems: cart,
    originalCartItems: cart,
    discountInput: null,
    totalDiscountAmt: 0,
    subTotal: cart.fold(0, (sum, i) => sum + i.lineSubtotal),
    freeItemCartKeys: const {},
    freeQtyByCartKey: const {},
  );

  group('evaluate', () {
    test('freeReward returnsCheapestItemPrice', () {
      final buyer = item(1, 20000);
      final reward = item(2, 5000);
      expect(
        evaluator.evaluate(
          promo(
            buyProductIds: const [1],
            rewardProductIds: const [2],
            rewardType: 'FREE',
          ),
          ctx([buyer, reward]),
        ),
        closeTo(5000, 0.01),
      );
    });

    test('returnsZero whenBuyConditionNotMet', () {
      final line = item(1, 10000);
      expect(
        evaluator.evaluate(
          promo(
            buyProductIds: const [1],
            rewardProductIds: const [1],
            rewardType: 'FREE',
            buyQty: 2,
            getQty: 1,
          ),
          ctx([line]), // only 1 unit, need 2
        ),
        closeTo(0, 0.01),
      );
    });

    test('percentageReward usesNetPrice', () {
      final buyer = item(1, 20000);
      final reward = item(2, 10000);
      expect(
        evaluator.evaluate(
          promo(
            buyProductIds: const [1],
            rewardProductIds: const [2],
            rewardType: 'PERCENTAGE',
            rewardValue: 50,
          ),
          ctx([buyer, reward]),
        ),
        closeTo(5000, 0.01),
      );
    });
  });

  group('perItemDeduction', () {
    test('returnsEmpty forFreeRewardType', () {
      final buyer = item(1, 20000);
      final reward = item(2, 5000);
      expect(
        evaluator.perItemDeduction(
          promo(
            buyProductIds: const [1],
            rewardProductIds: const [2],
            rewardType: 'FREE',
          ),
          ctx([buyer, reward]),
        ),
        isEmpty,
      );
    });

    test('returnsRewardItemKey forAmountReward', () {
      final buyer = item(1, 20000);
      final reward = item(2, 10000);
      final deductions = evaluator.perItemDeduction(
        promo(
          buyProductIds: const [1],
          rewardProductIds: const [2],
          rewardType: 'AMOUNT',
          rewardValue: 5000,
        ),
        ctx([buyer, reward]),
      );
      expect(deductions['2'] ?? 0, closeTo(5000, 0.01));
    });

    test('amountRewardCapsEachRewardItemIndividually', () {
      final buyer = item(1, 49000);
      final firstReward = item(2, 22000);
      final secondReward = item(3, 19000);
      final deductions = evaluator.perItemDeduction(
        promo(
          buyProductIds: const [1],
          rewardProductIds: const [2, 3],
          rewardType: 'AMOUNT',
          rewardValue: 20000,
          getQty: 2,
        ),
        ctx([buyer, firstReward, secondReward]),
      );
      expect(deductions['2'] ?? 0, closeTo(20000, 0.01));
      expect(deductions['3'] ?? 0, closeTo(19000, 0.01));
    });

    test('fixedPriceRewardUsesEachRewardItemSaving', () {
      final buyer = item(1, 49000);
      final firstReward = item(2, 20000);
      final secondReward = item(3, 21000);
      final deductions = evaluator.perItemDeduction(
        promo(
          buyProductIds: const [1],
          rewardProductIds: const [2, 3],
          rewardType: 'FIXED_PRICE',
          rewardValue: 9000,
          getQty: 2,
        ),
        ctx([buyer, firstReward, secondReward]),
      );
      expect(deductions['2'] ?? 0, closeTo(11000, 0.01));
      expect(deductions['3'] ?? 0, closeTo(12000, 0.01));
    });
  });

  group('itemRole', () {
    test('returnsQualifier forBuyItem', () {
      final buyer = item(1, 20000);
      final reward = item(2, 5000);
      final roles = evaluator.itemRole(
        promo(
          buyProductIds: const [1],
          rewardProductIds: const [2],
          rewardType: 'FREE',
        ),
        buyer,
        ctx([buyer, reward]),
      );
      expect(roles.length, 1);
      expect(roles.first.role, 'QUALIFIER');
      expect(roles.first.amt, closeTo(0, 0.01));
    });

    test('returnsReward forRewardItem', () {
      final buyer = item(1, 20000);
      final reward = item(2, 5000);
      final roles = evaluator.itemRole(
        promo(
          buyProductIds: const [1],
          rewardProductIds: const [2],
          rewardType: 'FREE',
        ),
        reward,
        ctx([buyer, reward]),
      );
      expect(roles.length, 1);
      expect(roles.first.role, 'REWARD');
    });

    test('returnsEmpty forUnrelatedItem', () {
      final buyer = item(1, 20000);
      final reward = item(2, 5000);
      final unrelated = item(3, 8000);
      expect(
        evaluator.itemRole(
          promo(
            buyProductIds: const [1],
            rewardProductIds: const [2],
            rewardType: 'FREE',
          ),
          unrelated,
          ctx([buyer, reward, unrelated]),
        ),
        isEmpty,
      );
    });

    test('returnsBothRoles forOverlapItem', () {
      // When buy and reward scope overlap on the same product, one line is both
      // QUALIFIER and REWARD. Cart: 3 units of product 1, BUY 2 GET 1 FREE.
      const line = CartItemData(
        productId: 1,
        productName: 'P1',
        price: 10000,
        quantity: 3,
        cartKey: '1',
      );
      final roles = evaluator.itemRole(
        promo(
          buyProductIds: const [1],
          rewardProductIds: const [1],
          rewardType: 'FREE',
          buyQty: 2,
          getQty: 1,
        ),
        line,
        ctx(const [line]),
      );
      final roleNames = roles.map((r) => r.role).toSet();
      expect(roleNames, contains('QUALIFIER'));
      expect(roleNames, contains('REWARD'));
    });
  });

  group('claimedRewardUnits', () {
    test('reports which product ids the promotion consumes as rewards', () {
      final buyer = item(1, 20000);
      final reward = item(2, 5000, qty: 2);
      final claimed = evaluator.claimedRewardUnits(
        promo(
          buyProductIds: const [1],
          rewardProductIds: const [2],
          rewardType: 'FREE',
        ),
        ctx([buyer, reward]),
      );
      expect(claimed, {2: 1});
    });

    test('is empty when the promotion delivers nothing', () {
      final line = item(1, 10000);
      final claimed = evaluator.claimedRewardUnits(
        promo(
          buyProductIds: const [1],
          rewardProductIds: const [1],
          rewardType: 'FREE',
          buyQty: 2,
        ),
        ctx([line]),
      );
      expect(claimed, isEmpty);
    });
  });
}
