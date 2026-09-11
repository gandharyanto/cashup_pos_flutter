import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/transaction_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `TransactionCalculatorComputePerItemSavingsTest.kt`, followed
/// by attribution, label and eligibility tests the Kotlin suite does not have.
///
/// The Kotlin sections are kept:
///  1. Baseline — selectedRewardQtyMap valid (reward is a distinct item)
///  2. Core bug case — selectedRewardQtyMap references the sole qualifier
///  3. Fallback verification — all selected items blocked, pool fires
///  4. rewardScope = ALL — always the available pool
///  5. Empty selectedRewardQtyMap — auto pool selection
void main() {
  CartItemData cartItem({
    required int productId,
    required String cartKey,
    required double price,
    required int qty,
    List<int> categoryIds = const [],
  }) => CartItemData(
    productId: productId,
    productName: 'Product-$productId',
    price: price,
    quantity: qty,
    cartKey: cartKey,
    categoryIds: categoryIds,
  );

  PromotionInput buyXGetYPromo({
    int promotionId = 1,
    String name = 'TestPromo',
    String rewardType = 'FREE',
    double? rewardValue,
    int buyQty = 1,
    int getQty = 1,
    String buyScope = 'PRODUCT',
    List<int> buyProductIds = const [],
    List<int> buyCategoryIds = const [],
    String rewardScope = 'PRODUCT',
    List<int> rewardProductIds = const [],
    List<int> rewardCategoryIds = const [],
    Map<String, int> selectedRewardQtyMap = const {},
  }) => PromotionInput(
    promotionId: promotionId,
    name: name,
    promoType: 'BUY_X_GET_Y',
    priority: 1,
    canCombine: false,
    rewardType: rewardType,
    rewardValue: rewardValue,
    buyQty: buyQty,
    getQty: getQty,
    buyScope: buyScope,
    buyProductIds: buyProductIds,
    buyCategoryIds: buyCategoryIds,
    rewardScope: rewardScope,
    rewardProductIds: rewardProductIds,
    rewardCategoryIds: rewardCategoryIds,
    selectedRewardQtyMap: selectedRewardQtyMap,
  );

  double savingOf(PerItemSavingsResult result, String cartKey) =>
      result.savings[cartKey] ?? 0;

  group('computePerItemSavings', () {
    // ─── 1. Baseline ───────────────────────────────────────────────────────

    // Cart: productA x2 (qualifier), productB x1 (reward candidate).
    // Promo: BUY 1 productA GET 1 productB FREE, productB explicitly selected.
    test('given buy1productA_get1productB, when selectedRewardQtyMap picks productB, then savings on productB only', () {
      final productA = cartItem(
        productId: 1,
        cartKey: 'key-A',
        price: 20000,
        qty: 2,
      );
      final productB = cartItem(
        productId: 2,
        cartKey: 'key-B',
        price: 15000,
        qty: 1,
      );

      final promo = buyXGetYPromo(
        buyProductIds: [1],
        rewardProductIds: [2],
        selectedRewardQtyMap: {'key-B': 1},
      );

      final result = TransactionCalculator.computePerItemSavings(
        [productA, productB],
        null,
        [promo],
      );

      final savingsB = savingOf(result, 'key-B');
      expect(savingsB, greaterThan(0), reason: 'productB should save');
      expect(savingOf(result, 'key-A'), closeTo(0, 0.01));
      expect(savingsB, closeTo(15000, 0.01));
    });

    // ─── 2. Core bug case ──────────────────────────────────────────────────

    // Cart: kwtSiramDaging x1 (sole qualifier), prima x1. Reward scope covers
    // both; the user picked the qualifier. Before the fix the qualifier took
    // the saving; now its only unit is reserved and prima gets it.
    test('given self-referential promo, when selectedRewardQtyMap picks qualifier, then savings go to non-qualifier item', () {
      final kwtSiramDaging = cartItem(
        productId: 23,
        cartKey: 'key-kwt',
        price: 49000,
        qty: 1,
      );
      final prima = cartItem(
        productId: 7,
        cartKey: 'key-prima',
        price: 8000,
        qty: 1,
      );

      final promo = buyXGetYPromo(
        buyProductIds: [23],
        rewardProductIds: [23, 7],
        rewardType: 'FIXED_PRICE',
        rewardValue: 5000,
        selectedRewardQtyMap: {'key-kwt': 1},
      );

      final result = TransactionCalculator.computePerItemSavings(
        [kwtSiramDaging, prima],
        null,
        [promo],
      );

      expect(
        savingOf(result, 'key-kwt'),
        closeTo(0, 0.01),
        reason: 'qualifier kwtSiramDaging must not receive reward savings',
      );
      expect(
        savingOf(result, 'key-prima'),
        greaterThan(0),
        reason: 'prima (cheapest available reward) must receive savings',
      );
    });

    // ─── 3. Fallback verification ──────────────────────────────────────────

    // Same as case 2: prima saves (8000 − 5000) × 1 = 3000.
    test('given self-referential promo with FIXED_PRICE, when qualifier is blocked, then fallback savings value equals price minus fixedPrice', () {
      final kwtSiramDaging = cartItem(
        productId: 23,
        cartKey: 'key-kwt',
        price: 49000,
        qty: 1,
      );
      final prima = cartItem(
        productId: 7,
        cartKey: 'key-prima',
        price: 8000,
        qty: 1,
      );

      final promo = buyXGetYPromo(
        buyProductIds: [23],
        rewardProductIds: [23, 7],
        rewardType: 'FIXED_PRICE',
        rewardValue: 5000,
        selectedRewardQtyMap: {'key-kwt': 1},
      );

      final result = TransactionCalculator.computePerItemSavings(
        [kwtSiramDaging, prima],
        null,
        [promo],
      );

      expect(savingOf(result, 'key-prima'), closeTo(8000 - 5000, 0.01));
      expect(savingOf(result, 'key-kwt'), closeTo(0, 0.01));
    });

    // ─── 4. rewardScope = ALL ──────────────────────────────────────────────

    // productA x2, BUY 1 GET 1 FREE, rewardScope ALL with a selection. The
    // selection is ignored: one unit is reserved as qualifier, one is free.
    test('given rewardScope ALL, when selectedRewardQtyMap present, then availablePool is used and savings are correct', () {
      final productA = cartItem(
        productId: 1,
        cartKey: 'key-A',
        price: 20000,
        qty: 2,
      );

      final promo = buyXGetYPromo(
        buyProductIds: [1],
        rewardScope: 'ALL',
        selectedRewardQtyMap: {'key-A': 1},
      );

      final result = TransactionCalculator.computePerItemSavings(
        [productA],
        null,
        [promo],
      );

      expect(savingOf(result, 'key-A'), closeTo(20000, 0.01));
    });

    // ─── 5. Empty selectedRewardQtyMap ─────────────────────────────────────

    // productA x2, productB x1, both in reward scope, no selection. The promo
    // frees productB (15000) and the saving is spread across the whole pool
    // (productA's unreserved unit + productB); none of it is lost.
    test('given empty selectedRewardQtyMap, when auto pool selection runs, then cheapest reward item gets savings', () {
      final productA = cartItem(
        productId: 1,
        cartKey: 'key-A',
        price: 20000,
        qty: 2,
      );
      final productB = cartItem(
        productId: 2,
        cartKey: 'key-B',
        price: 15000,
        qty: 1,
      );

      final promo = buyXGetYPromo(buyProductIds: [1], rewardProductIds: [1, 2]);

      final result = TransactionCalculator.computePerItemSavings(
        [productA, productB],
        null,
        [promo],
      );

      final totalSavings = result.savings.values.fold<double>(
        0,
        (sum, s) => sum + s,
      );
      expect(totalSavings, greaterThan(0), reason: 'promo should fire');
      expect(totalSavings, closeTo(15000, 0.01));
      expect(savingOf(result, 'key-B'), greaterThan(0));
    });

    test('given amount reward over cheaper item price, when computing UI savings, then each reward item is capped individually', () {
      final buyer = cartItem(
        productId: 1,
        cartKey: 'key-buyer',
        price: 49000,
        qty: 1,
      );
      final firstReward = cartItem(
        productId: 2,
        cartKey: 'key-reward-1',
        price: 21000,
        qty: 1,
      );
      final secondReward = cartItem(
        productId: 3,
        cartKey: 'key-reward-2',
        price: 19000,
        qty: 1,
      );
      final promo = buyXGetYPromo(
        rewardType: 'AMOUNT',
        rewardValue: 20000,
        getQty: 2,
        buyScope: 'ALL',
        rewardProductIds: [2, 3],
        selectedRewardQtyMap: {'key-reward-1': 1, 'key-reward-2': 1},
      );

      final result = TransactionCalculator.computePerItemSavings(
        [buyer, firstReward, secondReward],
        null,
        [promo],
      );

      expect(savingOf(result, 'key-buyer'), closeTo(0, 0.01));
      expect(savingOf(result, 'key-reward-1'), closeTo(20000, 0.01));
      expect(savingOf(result, 'key-reward-2'), closeTo(19000, 0.01));
    });

    test('given fixed price reward, when computing UI savings, then each reward item uses its own price minus fixed price', () {
      final buyer = cartItem(
        productId: 1,
        cartKey: 'key-buyer',
        price: 49000,
        qty: 1,
      );
      final firstReward = cartItem(
        productId: 2,
        cartKey: 'key-reward-1',
        price: 20000,
        qty: 1,
      );
      final secondReward = cartItem(
        productId: 3,
        cartKey: 'key-reward-2',
        price: 21000,
        qty: 1,
      );
      final promo = buyXGetYPromo(
        rewardType: 'FIXED_PRICE',
        rewardValue: 9000,
        getQty: 2,
        buyProductIds: [1],
        rewardProductIds: [2, 3],
        selectedRewardQtyMap: {'key-reward-1': 1, 'key-reward-2': 1},
      );

      final result = TransactionCalculator.computePerItemSavings(
        [buyer, firstReward, secondReward],
        null,
        [promo],
      );

      expect(savingOf(result, 'key-buyer'), closeTo(0, 0.01));
      expect(savingOf(result, 'key-reward-1'), closeTo(11000, 0.01));
      expect(savingOf(result, 'key-reward-2'), closeTo(12000, 0.01));
    });

    test('given percentage discount and FREE reward qty one, UI savings keeps remaining paid qty visible', () {
      const categoryId = 6217366856903;
      const kwt = CartItemData(
        productId: 34322203648028,
        productName: 'KWT SIRAM DAGING',
        price: 49000,
        quantity: 1,
        cartKey: 'kwt',
        categoryIds: [categoryId],
      );
      const adjustable = CartItemData(
        productId: 35229856970016,
        productName: 'Product adjustable 2',
        price: 20000,
        basePrice: 20000,
        quantity: 2,
        cartKey: 'adjustable-2',
        categoryIds: [categoryId],
      );
      const discount = DiscountInput(
        discountId: 5,
        name: 'persentage',
        valueType: 'PERCENTAGE',
        value: 20,
      );
      final promo = buyXGetYPromo(
        promotionId: 20,
        name: 'Buy X get Y (free)',
        buyScope: 'CATEGORY',
        buyCategoryIds: [categoryId],
        rewardProductIds: [35197440779945, 35229856970016],
        rewardValue: 10,
      );

      final result = TransactionCalculator.computePerItemSavings(
        [kwt, adjustable],
        discount,
        [promo],
      );

      expect(savingOf(result, 'kwt'), closeTo(9800, 0.01));
      expect(savingOf(result, 'adjustable-2'), closeTo(24000, 0.01));
      expect(
        adjustable.lineSubtotal - savingOf(result, 'adjustable-2'),
        closeTo(16000, 0.01),
      );
    });

    test('given percentage discount and fully-free variant reward, UI savings does not exceed effective price', () {
      const categoryId = 6217366856903;
      const kwt = CartItemData(
        productId: 34322203648028,
        productName: 'KWT SIRAM DAGING',
        price: 49000,
        basePrice: 49000,
        quantity: 1,
        cartKey: 'kwt',
        categoryIds: [categoryId],
      );
      const pa2 = CartItemData(
        productId: 35229856970016,
        productName: 'Product adjustable 2',
        price: 10000,
        basePrice: 8000,
        quantity: 1,
        cartKey: 'pa2',
        categoryIds: [categoryId],
      );
      const discount = DiscountInput(
        discountId: 5,
        name: 'persentage',
        valueType: 'PERCENTAGE',
        value: 20,
      );
      final promo = buyXGetYPromo(
        promotionId: 20,
        name: 'Buy X get Y (free)',
        buyScope: 'CATEGORY',
        buyCategoryIds: [categoryId],
        rewardProductIds: [pa2.productId],
        rewardValue: 10,
      );

      final result = TransactionCalculator.computePerItemSavings(
        [kwt, pa2],
        discount,
        [promo],
      );

      expect(savingOf(result, 'kwt'), closeTo(9800, 0.01));
      expect(savingOf(result, 'pa2'), closeTo(10000, 0.01));
      expect(pa2.lineSubtotal - savingOf(result, 'pa2'), closeTo(0, 0.01));
    });
  });

  // Not in the Kotlin suite. Every expected figure below was produced by the
  // pinned Kotlin (33ddffdc) compiled with kotlinc, and is compared exactly so
  // a drift in operation order shows up.
  group('computePerItemSavings attribution beyond the Kotlin suite', () {
    CartItemData line(
      int id,
      double price,
      int qty,
      String key, [
      List<int> categoryIds = const [],
    ]) => CartItemData(
      productId: id,
      productName: 'P$id',
      price: price,
      quantity: qty,
      cartKey: key,
      categoryIds: categoryIds,
    );

    test('an empty cart has no savings', () {
      final result = TransactionCalculator.computePerItemSavings(
        const [],
        const DiscountInput(valueType: 'PERCENTAGE', value: 10),
        const [],
      );

      expect(result.isEmpty, isTrue);
      expect(result.labels, isEmpty);
    });

    test('order and item-subtotal promotions spread on top of a percentage '
        'discount, labels joined in the order the sources applied', () {
      final cart = [
        line(1, 30000, 1, 'a', [5]),
        line(2, 20000, 2, 'b', [6]),
        line(3, 15500, 1, 'c'),
      ];
      const discount = DiscountInput(
        discountId: 1,
        name: 'Member',
        valueType: 'PERCENTAGE',
        value: 10,
      );
      const order = PromotionInput(
        promotionId: 11,
        name: 'Order 10%',
        promoType: 'DISCOUNT_BY_ORDER',
        priority: 2,
        canCombine: true,
        valueType: 'PERCENTAGE',
        value: 10,
      );
      const itemSubtotal = PromotionInput(
        promotionId: 12,
        name: 'Item Rp3000',
        promoType: 'DISCOUNT_BY_ITEM_SUBTOTAL',
        priority: 1,
        canCombine: true,
        valueType: 'AMOUNT',
        value: 3000,
        buyScope: 'PRODUCT',
        buyProductIds: [2],
        isMultiplied: true,
      );

      final result = TransactionCalculator.computePerItemSavings(
        cart,
        discount,
        [order, itemSubtotal],
      );

      expect(result.savings, {
        'a': 5489.473684210527,
        'b': 13319.298245614034,
        'c': 2836.228070175439,
      });
      // Priority 1 (item subtotal) is attributed before priority 2 (order).
      expect(result.labels, {
        'a': 'Member + Order 10%',
        'b': 'Member + Item Rp3000 + Order 10%',
        'c': 'Member + Order 10%',
      });
    });

    // Two reward lines, so the split between them depends on each line's
    // net price — with the AMOUNT share rounded, as for a PERCENTAGE reward.
    test('a blank discount name saves without labelling, and a percentage '
        'reward is spread by rounded amount-discount net price', () {
      final cart = [
        line(1, 25000, 1, 'a'),
        line(2, 12345, 1, 'b'),
        line(3, 10001, 1, 'c'),
      ];
      const discount = DiscountInput(
        discountId: 2,
        name: '   ',
        valueType: 'AMOUNT',
        value: 7000,
      );
      const half = PromotionInput(
        promotionId: 21,
        name: 'Half',
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'PERCENTAGE',
        rewardValue: 50,
        buyQty: 1,
        getQty: 2,
        buyScope: 'PRODUCT',
        buyProductIds: [1],
        rewardScope: 'PRODUCT',
        rewardProductIds: [2, 3],
      );
      const flat = PromotionInput(
        promotionId: 22,
        name: 'Flat',
        promoType: 'DISCOUNT_BY_ORDER',
        priority: 2,
        canCombine: true,
        valueType: 'AMOUNT',
        value: 5000,
      );

      final result = TransactionCalculator.computePerItemSavings(
        cart,
        discount,
        [half, flat],
      );

      expect(result.savings, {
        'a': 6336.1625935656575,
        'b': 8388.722797799039,
        'c': 6796.114608635305,
      });
      expect(result.labels, {
        'b': 'Half + Flat',
        'c': 'Half + Flat',
        'a': 'Flat',
      });
      // Kotlin's LinkedHashMap order: the discount saved first but, being
      // unlabelled, created no label entry.
      expect(result.labels.keys, ['b', 'c', 'a']);
      expect(result.savings.keys, ['a', 'b', 'c']);
    });

    test('a capped category discount with a partly free line and an order '
        'percentage', () {
      final cart = [
        line(1, 49000, 1, 'a', [9]),
        line(2, 8000, 3, 'b', [9]),
      ];
      const discount = DiscountInput(
        discountId: 3,
        name: 'Cap',
        valueType: 'PERCENTAGE',
        value: 20,
        maxDiscountAmount: 5000,
        scope: 'CATEGORY',
        eligibleCategoryIds: [9],
      );
      const free = PromotionInput(
        promotionId: 31,
        name: 'Free prima',
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'FREE',
        buyQty: 1,
        getQty: 1,
        buyScope: 'PRODUCT',
        buyProductIds: [1],
        rewardScope: 'PRODUCT',
        rewardProductIds: [2],
      );
      const order = PromotionInput(
        promotionId: 32,
        name: 'Order5',
        promoType: 'DISCOUNT_BY_ORDER',
        priority: 2,
        canCombine: true,
        valueType: 'PERCENTAGE',
        value: 5,
      );

      final result = TransactionCalculator.computePerItemSavings(
        cart,
        discount,
        [free, order],
      );

      expect(result.savings, {'a': 5388.252955526365, 'b': 10091.199099268155});
      expect(result.labels, {
        'a': 'Cap + Order5',
        'b': 'Cap + Free prima + Order5',
      });
    });
  });

  // Expected booleans from the same kotlinc run.
  group('isDiscountEligible', () {
    const three = [
      CartItemData(
        productId: 1,
        productName: 'P1',
        price: 10000,
        quantity: 3,
        cartKey: 'a',
        categoryIds: [5],
      ),
    ];
    const all = DiscountInput(valueType: 'PERCENTAGE', value: 10);

    bool eligible(DiscountInput discount) =>
        TransactionCalculator.isDiscountEligible(discount, three, 30000);

    test('needs a positive value', () {
      expect(
        eligible(const DiscountInput(valueType: 'PERCENTAGE', value: 0)),
        isFalse,
      );
      expect(eligible(all), isTrue);
    });

    test('needs the minimum purchase met, inclusively', () {
      expect(
        eligible(
          const DiscountInput(
            valueType: 'PERCENTAGE',
            value: 10,
            minPurchase: 30001,
          ),
        ),
        isFalse,
      );
      expect(
        eligible(
          const DiscountInput(
            valueType: 'PERCENTAGE',
            value: 10,
            minPurchase: 30000,
          ),
        ),
        isTrue,
      );
    });

    test('PRODUCT and CATEGORY scopes need a matching line', () {
      expect(
        eligible(
          const DiscountInput(
            valueType: 'PERCENTAGE',
            value: 10,
            scope: 'PRODUCT',
            eligibleProductIds: [2],
          ),
        ),
        isFalse,
      );
      expect(
        eligible(
          const DiscountInput(
            valueType: 'PERCENTAGE',
            value: 10,
            scope: 'PRODUCT',
            eligibleProductIds: [1],
          ),
        ),
        isTrue,
      );
      expect(
        eligible(
          const DiscountInput(
            valueType: 'PERCENTAGE',
            value: 10,
            scope: 'CATEGORY',
            eligibleCategoryIds: [5],
          ),
        ),
        isTrue,
      );
      expect(
        eligible(
          const DiscountInput(
            valueType: 'PERCENTAGE',
            value: 10,
            scope: 'CATEGORY',
            eligibleCategoryIds: [6],
          ),
        ),
        isFalse,
      );
    });

    test('an unknown scope is never eligible', () {
      expect(
        eligible(
          const DiscountInput(
            valueType: 'PERCENTAGE',
            value: 10,
            scope: 'BRAND',
          ),
        ),
        isFalse,
      );
    });
  });

  group('isPromotionEligible', () {
    CartItemData qty(int n) => CartItemData(
      productId: 1,
      productName: 'P1',
      price: 10000,
      quantity: n,
      cartKey: 'a',
      categoryIds: const [5],
    );

    // A Monday. Every test outside the schedule group passes it explicitly,
    // so none of them depends on the machine clock.
    final monday = DateTime(2026, 9, 7, 12);

    bool eligible(PromotionInput promo, List<CartItemData> cart) =>
        TransactionCalculator.isPromotionEligible(
          promo,
          cart,
          cart.fold<double>(0, (sum, i) => sum + i.lineSubtotal),
          now: monday,
        );

    const orderMin3 = PromotionInput(
      promotionId: 1,
      promoType: 'DISCOUNT_BY_ORDER',
      priority: 1,
      canCombine: true,
      valueType: 'AMOUNT',
      value: 1000,
      buyQty: 3,
    );

    test('DISCOUNT_BY_ORDER needs a value and the total cart quantity', () {
      expect(
        eligible(
          const PromotionInput(
            promotionId: 1,
            promoType: 'DISCOUNT_BY_ORDER',
            priority: 1,
            canCombine: true,
            valueType: 'AMOUNT',
            value: 0,
          ),
          [qty(3)],
        ),
        isFalse,
      );
      expect(eligible(orderMin3, [qty(2)]), isFalse);
      expect(eligible(orderMin3, [qty(3)]), isTrue);
    });

    test('the minimum purchase is checked before the type', () {
      const promo = PromotionInput(
        promotionId: 1,
        promoType: 'DISCOUNT_BY_ORDER',
        priority: 1,
        canCombine: true,
        valueType: 'AMOUNT',
        value: 1000,
        minPurchase: 30001,
      );
      expect(eligible(promo, [qty(3)]), isFalse);
    });

    test('DISCOUNT_BY_ITEM_SUBTOTAL needs eligible lines reaching buyQty', () {
      const noMatch = PromotionInput(
        promotionId: 2,
        promoType: 'DISCOUNT_BY_ITEM_SUBTOTAL',
        priority: 1,
        canCombine: true,
        valueType: 'PERCENTAGE',
        value: 10,
        buyScope: 'PRODUCT',
        buyProductIds: [9],
      );
      const min3 = PromotionInput(
        promotionId: 2,
        promoType: 'DISCOUNT_BY_ITEM_SUBTOTAL',
        priority: 1,
        canCombine: true,
        valueType: 'PERCENTAGE',
        value: 10,
        buyScope: 'PRODUCT',
        buyProductIds: [1],
        buyQty: 3,
      );
      expect(eligible(noMatch, [qty(3)]), isFalse);
      expect(eligible(min3, [qty(2)]), isFalse);
      expect(eligible(min3, [qty(3)]), isTrue);
    });

    test('BUY_X_GET_Y reserves the buy units before counting rewards', () {
      const bothAll = PromotionInput(
        promotionId: 3,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'FREE',
        buyQty: 2,
        getQty: 1,
      );
      const sameProduct = PromotionInput(
        promotionId: 3,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'FREE',
        buyQty: 2,
        getQty: 1,
        buyScope: 'PRODUCT',
        buyProductIds: [1],
        rewardScope: 'PRODUCT',
        rewardProductIds: [1],
      );
      const noGetQty = PromotionInput(
        promotionId: 3,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'FREE',
        buyQty: 2,
        buyScope: 'PRODUCT',
        buyProductIds: [1],
        rewardScope: 'PRODUCT',
        rewardProductIds: [1],
      );

      expect(eligible(bothAll, [qty(3)]), isFalse);
      expect(eligible(sameProduct, [qty(2)]), isFalse);
      expect(eligible(sameProduct, [qty(3)]), isTrue);
      expect(eligible(noGetQty, [qty(3)]), isFalse);
    });

    test('a FIXED_PRICE reward needs a line priced above the fixed price', () {
      const cart = [
        CartItemData(
          productId: 1,
          productName: 'P1',
          price: 10000,
          quantity: 1,
          cartKey: 'q',
        ),
        CartItemData(
          productId: 2,
          productName: 'P2',
          price: 9000,
          quantity: 1,
          cartKey: 'r',
        ),
      ];
      PromotionInput fixedAt(double fixedPrice) => PromotionInput(
        promotionId: 4,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'FIXED_PRICE',
        rewardValue: fixedPrice,
        buyQty: 1,
        getQty: 1,
        buyScope: 'PRODUCT',
        buyProductIds: const [1],
        rewardScope: 'PRODUCT',
        rewardProductIds: const [2],
      );

      expect(eligible(fixedAt(9000), cart), isFalse);
      expect(eligible(fixedAt(8999), cart), isTrue);
    });

    test('an unknown promotion type is never eligible', () {
      const promo = PromotionInput(
        promotionId: 1,
        promoType: 'BUNDLE',
        priority: 1,
        canCombine: true,
        valueType: 'AMOUNT',
        value: 1000,
      );
      expect(eligible(promo, [qty(3)]), isFalse);
    });

    // Kotlin reads the system clock, so these follow its rules by reading
    // rather than by a run; the time parser is pinned to the kotlinc run.
    group('schedule', () {
      PromotionInput scheduled({
        List<String> activeDays = const [],
        String? start,
        String? end,
      }) => PromotionInput(
        promotionId: 5,
        promoType: 'DISCOUNT_BY_ORDER',
        priority: 1,
        canCombine: true,
        valueType: 'AMOUNT',
        value: 1000,
        activeDays: activeDays,
        activeStartTime: start,
        activeEndTime: end,
      );

      bool at(PromotionInput promo, DateTime now) =>
          TransactionCalculator.isPromotionEligible(
            promo,
            [qty(1)],
            10000,
            now: now,
          );

      test('no days and no start time is always active', () {
        expect(at(scheduled(), monday), isTrue);
      });

      test('active days are matched against the weekday', () {
        expect(at(scheduled(activeDays: ['TUE']), monday), isFalse);
        expect(at(scheduled(activeDays: ['MON', 'TUE']), monday), isTrue);
        expect(
          at(scheduled(activeDays: ['SUN']), DateTime(2026, 9, 13, 12)),
          isTrue,
        );
      });

      test('the time window is inclusive at both ends, to the minute', () {
        final promo = scheduled(start: '09:00', end: '17:00');
        expect(at(promo, DateTime(2026, 9, 7, 8, 59, 59)), isFalse);
        expect(at(promo, DateTime(2026, 9, 7, 9)), isTrue);
        expect(at(promo, DateTime(2026, 9, 7, 17, 0, 59)), isTrue);
        expect(at(promo, DateTime(2026, 9, 7, 17, 1)), isFalse);
      });

      test('a start time without an end time does not restrict', () {
        expect(at(scheduled(start: '23:00'), DateTime(2026, 9, 7, 1)), isTrue);
      });

      test('days and time must both match', () {
        final promo = scheduled(
          activeDays: ['MON'],
          start: '09:00',
          end: '17:00',
        );
        expect(at(promo, DateTime(2026, 9, 7, 18)), isFalse);
        expect(at(promo, DateTime(2026, 9, 8, 10)), isFalse);
        expect(at(promo, monday), isTrue);
      });

      // kotlinc parseTimeToMinutes: ' 9:00' → 0, '0x10:00' → 0,
      // '+9:05' → 545, '9' → 540, 'ab:15' → 15, '-1:30' → -30.
      // Dart's int.tryParse would read ' 9' and '0x10' as numbers.
      test('times parse the way Kotlin toIntOrNull does', () {
        final eight = DateTime(2026, 9, 7, 8);
        // ' 9:00' starts at minute 0, so 08:00 is inside it.
        expect(at(scheduled(start: ' 9:00', end: '17:00'), eight), isTrue);
        expect(at(scheduled(start: '0x10:00', end: '17:00'), eight), isTrue);
        // '+9:05' is 09:05 and '9' is 09:00.
        expect(
          at(
            scheduled(start: '+9:05', end: '17:00'),
            DateTime(2026, 9, 7, 9, 4),
          ),
          isFalse,
        );
        expect(
          at(scheduled(start: '9', end: '17:00'), DateTime(2026, 9, 7, 9)),
          isTrue,
        );
        expect(
          at(scheduled(start: '9', end: '17:00'), DateTime(2026, 9, 7, 8, 59)),
          isFalse,
        );
        // 'ab:15' is minute 15; '-1:30' is minute -30.
        expect(
          at(
            scheduled(start: 'ab:15', end: '17:00'),
            DateTime(2026, 9, 7, 0, 14),
          ),
          isFalse,
        );
        expect(
          at(scheduled(start: '00:00', end: '-1:30'), DateTime(2026, 9, 7)),
          isFalse,
        );
      });
    });
  });
}
