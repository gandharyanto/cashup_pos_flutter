import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/promotion/buyxgety/amount_reward_strategy.dart';
import 'package:cashup_pos/src/calc/promotion/buyxgety/fixed_price_reward_strategy.dart';
import 'package:cashup_pos/src/calc/promotion/buyxgety/percentage_reward_strategy.dart';
import 'package:cashup_pos/src/calc/promotion/evaluation_context.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `PercentageRewardStrategyTest.kt`,
/// `AmountRewardStrategyTest.kt` and `FixedPriceRewardStrategyTest.kt`.
void main() {
  CartItemData item(int id, double price, {int qty = 1}) => CartItemData(
    productId: id,
    productName: 'P$id',
    price: price,
    quantity: qty,
    cartKey: '$id',
  );

  PromotionInput promo(String rewardType, double rewardValue) => PromotionInput(
    promotionId: 1,
    promoType: 'BUY_X_GET_Y',
    priority: 1,
    canCombine: false,
    rewardType: rewardType,
    rewardValue: rewardValue,
    buyQty: 1,
    getQty: 1,
  );

  EvaluationContext ctx({
    DiscountInput? discountInput,
    double totalDiscountAmt = 0,
    List<CartItemData> cart = const [],
  }) => EvaluationContext(
    cartItems: cart,
    originalCartItems: cart,
    discountInput: discountInput,
    totalDiscountAmt: totalDiscountAmt,
    subTotal: cart.fold(0, (sum, i) => sum + i.lineSubtotal),
    freeItemCartKeys: const {},
    freeQtyByCartKey: const {},
  );

  group('PercentageRewardStrategy', () {
    const strategy = PercentageRewardStrategy();

    test('calculateAmount appliesPercentageOnNetPrice', () {
      final line = item(1, 10000);
      const discount = DiscountInput(valueType: 'PERCENTAGE', value: 50);
      // netPrice = (10000 - 2000) / 1 = 8000; 50% of 8000 = 4000
      expect(
        strategy.calculateAmount(
          [line],
          1,
          promo('PERCENTAGE', 50),
          ctx(discountInput: discount, totalDiscountAmt: 2000, cart: [line]),
        ),
        closeTo(4000, 0.01),
      );
    });

    test('calculateAmount selectsCheapestByNetPrice', () {
      final expensive = item(1, 20000);
      final cheap = item(2, 5000);
      expect(
        strategy.calculateAmount(
          [expensive, cheap],
          1,
          promo('PERCENTAGE', 100),
          ctx(cart: [expensive, cheap]),
        ),
        closeTo(5000, 0.01),
      );
    });

    test('calculateAmount roundsToNearestRupiah', () {
      // 10% of 9999 = 999.9 -> Math.round -> 1000
      final line = item(1, 9999);
      expect(
        strategy.calculateAmount(
          [line],
          1,
          promo('PERCENTAGE', 10),
          ctx(cart: [line]),
        ),
        closeTo(1000, 0.01),
      );
    });
  });

  group('AmountRewardStrategy', () {
    const strategy = AmountRewardStrategy();

    test('calculateAmount flatAmountPerUnit', () {
      final line = item(1, 20000);
      expect(
        strategy.calculateAmount(
          [line],
          1,
          promo('AMOUNT', 5000),
          ctx(cart: [line]),
        ),
        closeTo(5000, 0.01),
      );
    });

    test('calculateAmount cappedAtNetSubtotalOfRewardItems', () {
      final line = item(1, 10000);
      expect(
        strategy.calculateAmount(
          [line],
          1,
          promo('AMOUNT', 50000),
          ctx(cart: [line]),
        ),
        closeTo(10000, 0.01),
      );
    });

    test('calculateAmount capsEachRewardUnitIndividually', () {
      final first = item(1, 22000);
      final second = item(2, 19000);
      // Cheapest first: min(20000,19000) + min(20000,22000) = 19000 + 20000
      expect(
        strategy.calculateAmount(
          [first, second],
          2,
          promo('AMOUNT', 20000),
          ctx(cart: [first, second]),
        ),
        closeTo(39000, 0.01),
      );
    });

    test('calculateAmount selectsCheapestByNetPrice beforeCap', () {
      final expensive = item(1, 30000);
      final cheap = item(2, 5000);
      expect(
        strategy.calculateAmount(
          [expensive, cheap],
          1,
          promo('AMOUNT', 3000),
          ctx(cart: [expensive, cheap]),
        ),
        closeTo(3000, 0.01),
      );
    });
  });

  group('FixedPriceRewardStrategy', () {
    const strategy = FixedPriceRewardStrategy();

    test('calculateAmount savingIsDifferenceFromFixedPrice', () {
      final line = item(1, 10000);
      expect(
        strategy.calculateAmount(
          [line],
          1,
          promo('FIXED_PRICE', 3000),
          ctx(cart: [line]),
        ),
        closeTo(7000, 0.01),
      );
    });

    test('calculateAmount zeroSaving whenFixedPriceGeNetPrice', () {
      final line = item(1, 5000);
      expect(
        strategy.calculateAmount(
          [line],
          1,
          promo('FIXED_PRICE', 8000),
          ctx(cart: [line]),
        ),
        closeTo(0, 0.01),
      );
    });

    test('calculateAmount multipliedByEffectiveQty', () {
      final line = item(1, 10000, qty: 3);
      expect(
        strategy.calculateAmount(
          [line],
          2,
          promo('FIXED_PRICE', 4000),
          ctx(cart: [line]),
        ),
        closeTo(12000, 0.01),
      );
    });

    test('calculateAmount sumsEachRewardUnitSavingIndividually', () {
      final first = item(1, 20000);
      final second = item(2, 21000);
      expect(
        strategy.calculateAmount(
          [first, second],
          2,
          promo('FIXED_PRICE', 9000),
          ctx(cart: [first, second]),
        ),
        closeTo(23000, 0.01),
      );
    });
  });
}
