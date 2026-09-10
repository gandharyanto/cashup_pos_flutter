import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/transaction_calculator.dart';
import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `TransactionCalculatorTest.kt` — the `calculateTransaction`
/// half. The payload half lives in `transaction_calculator_payload_test.dart`.
///
/// Test names and numbers are kept as they are; several came from production
/// mismatches and the comments record the server figures they reproduce.
void main() {
  const settings = PaymentSetting(
    paymentSettingId: 1,
    isPriceIncludeTax: true,
    isRounding: false,
    roundingTarget: 0,
    roundingType: 'NONE',
    isServiceCharge: false,
    serviceChargePercentage: 0,
    serviceChargeAmount: 0,
    isTax: true,
    taxPercentage: 10,
    taxName: 'PB1',
  );

  TransactionCalculationResult calculate({
    required List<CartItemData> cartItems,
    PaymentSetting? paymentSettings,
    String paymentMethod = 'QRIS',
    bool priceIncludeTax = false,
    DiscountInput? discountInput,
    List<PromotionInput> promotions = const [],
  }) => TransactionCalculator.calculateTransaction(
    TransactionCalculationInput(
      cartItems: cartItems,
      paymentSettings: paymentSettings,
      paymentMethod: paymentMethod,
      priceIncludeTax: priceIncludeTax,
      discountInput: discountInput,
      promotions: promotions,
    ),
  );

  CartItemData plain(
    int id,
    double price, {
    int qty = 1,
    String? cartKey,
    String? name,
  }) => CartItemData(
    productId: id,
    productName: name ?? 'P$id',
    price: price,
    quantity: qty,
    cartKey: cartKey ?? '$id',
  );

  PromotionInput bxgy({
    required int id,
    required String rewardType,
    double? rewardValue,
    int priority = 1,
    int buyQty = 1,
    int getQty = 1,
    List<int> buyProductIds = const [],
    List<int> rewardProductIds = const [],
    bool isMultiplied = false,
    String buyScope = 'PRODUCT',
    String rewardScope = 'PRODUCT',
  }) => PromotionInput(
    promotionId: id,
    promoType: 'BUY_X_GET_Y',
    priority: priority,
    canCombine: true,
    buyQty: buyQty,
    getQty: getQty,
    rewardType: rewardType,
    rewardValue: rewardValue,
    isMultiplied: isMultiplied,
    buyScope: buyScope,
    buyProductIds: buyProductIds,
    rewardScope: rewardScope,
    rewardProductIds: rewardProductIds,
  );

  group('tax', () {
    test('priceIncludeTax roundsTaxPerLineItem', () {
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'Prima 600ml',
            price: 8000,
            quantity: 2,
            cartKey: '1',
            taxAmountPerUnit: 727.27,
            isTaxable: true,
            taxId: 10,
            taxName: 'PB1',
            taxPercentage: 10,
          ),
        ],
        paymentSettings: settings,
        priceIncludeTax: true,
      );

      expect(result.tax, 1454.55);
      expect(result.transactionItems.single.taxAmount, '1454.55');
    });

    test('priceIncludeTax keepsSingleQuantityValue', () {
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'KWT SIRAM DAGING',
            price: 49000,
            quantity: 1,
            cartKey: '1',
            taxAmountPerUnit: 4454.55,
            isTaxable: true,
            taxId: 10,
            taxName: 'PB1',
            taxPercentage: 10,
          ),
        ],
        paymentSettings: settings,
        priceIncludeTax: true,
      );

      expect(result.tax, 4454.55);
      expect(result.transactionItems.single.taxAmount, '4454.55');
    });

    test('taxExclusive usesPercentageForTaxAmount', () {
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'Pecel Ayam',
            price: 27000,
            quantity: 1,
            cartKey: '1',
            taxAmountPerUnit: 2500,
            isTaxable: true,
            taxId: 12,
            taxName: 'PB1',
            taxPercentage: 10,
          ),
        ],
        paymentSettings: settings.copyWith(
          isPriceIncludeTax: false,
          taxPercentage: 10,
        ),
        paymentMethod: 'GOFOOD',
      );

      expect(result.tax, 2700.0);
      expect(result.transactionItems.single.taxAmount, '2700');
      expect(result.totalAmount, 29700.0);
    });

    test('taxExclusive recalculatesTaxFromEffectivePrice', () {
      // The tax follows the effective price (29000), not the base price
      // (25000) the variants were added to.
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 34776030309022,
            productName: 'Pecel Ayam',
            price: 29000,
            basePrice: 25000,
            quantity: 1,
            cartKey: '34776030309022',
            taxAmountPerUnit: 2500,
            isTaxable: true,
            taxId: 12,
            taxName: 'PB1',
            taxPercentage: 10,
          ),
        ],
        paymentSettings: settings.copyWith(
          isPriceIncludeTax: false,
          taxPercentage: 10,
        ),
        paymentMethod: 'GOFOOD',
      );

      expect(result.tax, 2900.0);
      expect(result.transactionItems.single.taxAmount, '2900');
    });

    test('transactionItems taxAmount reflects post-discount-and-promotion tax for tax-exclusive', () {
      // 20000 taxed at 10%, discount 10%, promo DISCOUNT_BY_ORDER 5%.
      // discount = 2000 -> net 18000; promo = 18000 x 5% = 900
      // tax base = 20000 - 2000 - 900 = 17100 -> tax = 1710
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'Item A',
            price: 20000,
            quantity: 1,
            cartKey: '1',
            isTaxable: true,
            taxId: 1,
            taxName: 'PPN',
            taxPercentage: 10,
          ),
        ],
        discountInput: const DiscountInput(valueType: 'PERCENTAGE', value: 10),
        promotions: const [
          PromotionInput(
            promotionId: 1,
            promoType: 'DISCOUNT_BY_ORDER',
            priority: 1,
            canCombine: true,
            valueType: 'PERCENTAGE',
            value: 5,
          ),
        ],
      );

      expect(result.discountAmount, 2000.0);
      expect(result.promotionAmount, closeTo(900, 0.01));
      expect(result.tax, closeTo(1710, 0.01));
      // Tax-exclusive uses the "0.##" shape, so trailing zeros are dropped.
      expect(result.transactionItems.single.taxAmount, '1710');
    });

    test('transactionItems taxAmount reflects post-discount-and-promotion tax for tax-inclusive', () {
      // Tax inclusive: tax = (price x qty - promo) x rate/(1+rate)
      //              = (10000 - 5000) x 0.1/1.1 = 454.55
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'Item B',
            price: 10000,
            quantity: 1,
            cartKey: '1',
            isTaxable: true,
            taxId: 1,
            taxName: 'PPN',
            taxPercentage: 10,
          ),
        ],
        priceIncludeTax: true,
        promotions: const [
          PromotionInput(
            promotionId: 1,
            promoType: 'DISCOUNT_BY_ORDER',
            priority: 1,
            canCombine: true,
            valueType: 'AMOUNT',
            value: 5000,
          ),
        ],
      );

      expect(result.promotionAmount, 5000.0);
      expect(result.tax, closeTo(454.55, 0.01));
      expect(result.transactionItems.single.taxAmount, '454.55');
    });

    test(
      'transactionItems taxAmount is zero for BUY_X_GET_Y FREE reward item',
      () {
        final gula = plain(1, 10000, name: 'Gula');
        const prima = CartItemData(
          productId: 2,
          productName: 'Prima',
          price: 8000,
          quantity: 1,
          cartKey: '2',
          isTaxable: true,
          taxId: 1,
          taxName: 'PPN',
          taxPercentage: 10,
        );

        final result = calculate(
          cartItems: [gula, prima],
          promotions: [
            bxgy(
              id: 1,
              rewardType: 'FREE',
              buyProductIds: const [1],
              rewardProductIds: const [2],
            ),
          ],
        );

        expect(result.tax, 0.0);
        final primaItem = result.transactionItems.firstWhere(
          (i) => i.productId == 2,
        );
        expect(primaItem.taxAmount, isNull);
      },
    );

    test('amountDiscount category taxMatchesBeIntegerRounding', () {
      // Reproduces server tax=764.40 vs client 764.35.
      //
      // AMOUNT discount 12000 scoped to one category across two eligible lines:
      //   Ladah share      = round(12000 x 5500/22166)  = 2978
      //   ProductAdj share = round(12000 x 16666/22166) = 9022
      //   taxBase          = 16666 - 9022 = 7644 -> tax = 764.40
      //
      // The client's tax base uses the *raw* share rather than the rounded one,
      // which is why the assertion allows the 0.05 gap the Kotlin test allows.
      const categoryId = 99;
      const capucinno = CartItemData(
        productId: 34808446499093,
        productName: 'Capucinno',
        price: 20000,
        quantity: 1,
        cartKey: '34808446499093',
      );
      const ladahPutih = CartItemData(
        productId: 33511798896253,
        productName: 'Ladah putih',
        price: 5500,
        quantity: 1,
        cartKey: '33511798896253',
        categoryIds: [categoryId],
      );
      const productAdjustable = CartItemData(
        productId: 35197440779945,
        productName: 'Product Adjustable',
        price: 16666,
        quantity: 1,
        cartKey: '35197440779945',
        isTaxable: true,
        taxId: 2,
        taxName: 'Tax',
        taxPercentage: 10,
        categoryIds: [categoryId],
        isPriceAdjustable: true,
        isPriceOverride: true,
      );

      final result = calculate(
        cartItems: const [capucinno, ladahPutih, productAdjustable],
        paymentMethod: 'GRABFOOD',
        discountInput: const DiscountInput(
          discountId: 6,
          valueType: 'AMOUNT',
          value: 12000,
          scope: 'CATEGORY',
          eligibleCategoryIds: [categoryId],
        ),
      );

      expect(
        result.tax,
        closeTo(764.35, 0.005),
        reason: 'totalTax should match BE raw discount share',
      );
      expect(result.subTotal, closeTo(42166, 0.01));
      expect(result.discountAmount, closeTo(12000, 0.01));
    });
  });

  group('promotions', () {
    test(
      'buyXGetY percentage scopeAll multiQty distributesRewardUnitsNotItems',
      () {
        // Reproduces client=1201 vs server=2401.
        // Buy 1 get 2 at 10% off, scope ALL, not multiplied. The reward is two
        // *units*, both from the cheapest line -- not one unit per line.
        final gula = plain(1, 70000, qty: 3, name: 'Gula 1kg');
        final minyak = plain(2, 21000, qty: 3, name: 'Minyak goreng');
        final tepung = plain(3, 12007, qty: 3, name: 'Tepung terigu');

        final result = calculate(
          cartItems: [gula, minyak, tepung],
          paymentMethod: 'GOFOOD',
          promotions: [
            bxgy(
              id: 26,
              rewardType: 'PERCENTAGE',
              rewardValue: 10,
              buyQty: 1,
              getQty: 2,
              buyScope: 'ALL',
              rewardScope: 'ALL',
            ).copyWith(),
          ],
        );

        // 2 x 12007 x 10% = 2401.4 -> 2401
        expect(result.promotionAmount, 2401.0);
        expect(result.appliedPromotionIds, [26]);
        expect(result.totalAmount, 309021.0 - 2401.0);
      },
    );

    test('freePrioritizedOverPercentageEvenWithLowerSortPriority', () {
      // The FREE promo has the numerically weaker priority but still runs first,
      // which cancels the PERCENTAGE promo targeting the same reward.
      final gula = plain(1, 10000, name: 'Gula');
      final prima = plain(2, 8000, name: 'Prima');

      final result = calculate(
        cartItems: [gula, prima],
        promotions: [
          bxgy(
            id: 10,
            rewardType: 'PERCENTAGE',
            rewardValue: 10,
            priority: 1,
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
          bxgy(
            id: 20,
            rewardType: 'FREE',
            priority: 2,
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
        ],
      );

      expect(result.promotionAmount, 8000.0);
      expect(result.appliedPromotionIds, [20]);
      expect(result.totalAmount, 10000.0);
    });

    test('stackedPromoOnSameRewardItemIsCancelled', () {
      final gula = plain(1, 10000, name: 'Gula');
      final prima = plain(2, 8000, name: 'Prima');

      final result = calculate(
        cartItems: [gula, prima],
        promotions: [
          bxgy(
            id: 1,
            rewardType: 'FREE',
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
          bxgy(
            id: 2,
            rewardType: 'PERCENTAGE',
            rewardValue: 10,
            priority: 2,
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
        ],
      );

      expect(result.promotionAmount, 8000.0);
      expect(result.appliedPromotionIds, [1]);
      expect(result.totalAmount, 10000.0);
    });

    test('distinctRewardItemsAllowBothPromosToApply', () {
      final gula = plain(1, 10000, name: 'Gula');
      final prima = plain(2, 8000, name: 'Prima');
      final susu = plain(3, 6000, name: 'Susu');

      final result = calculate(
        cartItems: [gula, prima, susu],
        promotions: [
          bxgy(
            id: 1,
            rewardType: 'FREE',
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
          bxgy(
            id: 2,
            rewardType: 'PERCENTAGE',
            rewardValue: 10,
            priority: 2,
            buyProductIds: const [1],
            rewardProductIds: const [3],
          ),
        ],
      );

      // prima FREE = 8000, susu 10% = 600
      expect(result.promotionAmount, 8600.0);
      expect(result.appliedPromotionIds, [1, 2]);
    });

    test('twoPromosEachRewardDifferentUnitOfSameProduct', () {
      final gula = plain(1, 10000, qty: 2, name: 'Gula');
      final prima = plain(2, 8000, qty: 2, name: 'Prima');

      final result = calculate(
        cartItems: [gula, prima],
        promotions: [
          bxgy(
            id: 1,
            rewardType: 'FREE',
            priority: 2,
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
          bxgy(
            id: 2,
            rewardType: 'PERCENTAGE',
            rewardValue: 10,
            priority: 1,
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
        ],
      );

      // FREE takes one Prima unit (8000); PERCENTAGE takes 10% of the other (800).
      expect(result.promotionAmount, 8800.0);
      expect(result.appliedPromotionIds, [1, 2]);
      expect(result.totalAmount, 27200.0);
    });

    test('promoBlockedWhenAllUnitsOfRewardProductClaimed', () {
      final gula = plain(1, 10000, name: 'Gula');
      final prima = plain(2, 8000, name: 'Prima');

      final result = calculate(
        cartItems: [gula, prima],
        promotions: [
          bxgy(
            id: 1,
            rewardType: 'FREE',
            priority: 2,
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
          bxgy(
            id: 2,
            rewardType: 'PERCENTAGE',
            rewardValue: 10,
            priority: 1,
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
        ],
      );

      expect(result.promotionAmount, 8000.0);
      expect(result.appliedPromotionIds, [1]);
      expect(result.totalAmount, 10000.0);
    });

    test('discountByOrder appliesWhenMappedFromRewardValueTypeAndRewardDiscountValue', () {
      // The API sends rewardValueType/rewardDiscountValue for DISCOUNT_BY_ORDER;
      // the mapper turns them into valueType/value before the engine sees them.
      final result = calculate(
        cartItems: [plain(1, 20000, name: 'Item A')],
        paymentSettings: settings,
        priceIncludeTax: true,
        promotions: const [
          PromotionInput(
            promotionId: 11,
            promoType: 'DISCOUNT_BY_ORDER',
            priority: 1,
            canCombine: true,
            valueType: 'AMOUNT',
            value: 5000,
          ),
        ],
      );

      expect(result.promotionAmount, 5000.0);
      expect(result.appliedPromotionIds, [11]);
      expect(result.totalAmount, 15000.0);
    });

    test('discountByItemSubtotal fixedAmountAppliedOnceWhenNotMultiplied', () {
      // qty=2, AMOUNT=30000, isMultiplied=false -> 30000, not 60000.
      final result = calculate(
        cartItems: [plain(1, 55998, qty: 2, name: 'KWT GOR DAGING')],
        paymentSettings: settings,
        paymentMethod: 'SHOPEEFOOD',
        promotions: const [
          PromotionInput(
            promotionId: 11,
            promoType: 'DISCOUNT_BY_ITEM_SUBTOTAL',
            priority: 1,
            canCombine: true,
            valueType: 'AMOUNT',
            value: 30000,
            minPurchase: 100000,
            buyQty: 1,
          ),
        ],
      );

      expect(result.promotionAmount, 30000.0);
      expect(result.appliedPromotionIds, [11]);
      expect(result.totalAmount, 81996.0);
    });

    test('DISCOUNT_BY_ITEM_SUBTOTAL PERCENTAGE uses per-item integer rounding matching server', () {
      // Reproduces 400 "Total promotion mismatch: client=3733.32, server=3733.00".
      // Brokoli 20000 x 12% = 2400.00, buah 11111 x 12% = 1333.32.
      // The server rounds each line first: 2400 + 1333 = 3733.
      const brokoli = CartItemData(
        productId: 34419452218241,
        productName: 'Brokoli',
        price: 20000,
        quantity: 1,
        cartKey: '34419452218241',
      );
      const buah = CartItemData(
        productId: 34516700788454,
        productName: 'buah',
        price: 11111,
        quantity: 1,
        cartKey: '34516700788454',
        isTaxable: true,
        taxId: 2,
        taxPercentage: 10,
      );

      final result = calculate(
        cartItems: const [brokoli, buah],
        paymentSettings: settings,
        paymentMethod: 'Credit/Debit',
        promotions: const [
          PromotionInput(
            promotionId: 25,
            promoType: 'DISCOUNT_BY_ITEM_SUBTOTAL',
            priority: 1,
            canCombine: true,
            valueType: 'PERCENTAGE',
            value: 12,
          ),
        ],
      );

      expect(result.promotionAmount, 3733.0);
      // taxAppliedAfterDiscount: buah net = 11111 - 1333 = 9778 -> 977.80
      expect(result.tax, closeTo(977.80, 0.01));
    });

    test('BXGY AMOUNT then DISCOUNT_BY_ORDER PERCENTAGE does not reduce order base', () {
      // A non-FREE BUY_X_GET_Y reward is a per-item discount, so the item stays
      // in the order and DISCOUNT_BY_ORDER still computes from the full 50000.
      // Only a fully FREE reward removes an item from the base.
      final qualifier = plain(1, 30000, name: 'Qualifier');
      final reward = plain(2, 20000, name: 'Reward');

      final result = calculate(
        cartItems: [qualifier, reward],
        paymentMethod: 'CASH',
        promotions: [
          bxgy(
            id: 1,
            rewardType: 'AMOUNT',
            rewardValue: 10000,
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
          const PromotionInput(
            promotionId: 2,
            promoType: 'DISCOUNT_BY_ORDER',
            priority: 2,
            canCombine: true,
            valueType: 'PERCENTAGE',
            value: 10,
          ),
        ],
      );

      // 10000 + 10% x 50000 = 15000
      expect(result.promotionAmount, closeTo(15000, 0.01));
    });

    test('promotion sort priority then id as tiebreaker', () {
      final result = calculate(
        cartItems: [plain(1, 20000, name: 'Item')],
        paymentMethod: 'CASH',
        promotions: const [
          // Intentionally reversed: id 20 first in the list, id 10 second.
          PromotionInput(
            promotionId: 20,
            promoType: 'DISCOUNT_BY_ORDER',
            priority: 1,
            canCombine: true,
            valueType: 'AMOUNT',
            value: 5000,
          ),
          PromotionInput(
            promotionId: 10,
            promoType: 'DISCOUNT_BY_ORDER',
            priority: 1,
            canCombine: true,
            valueType: 'AMOUNT',
            value: 5000,
          ),
        ],
      );

      expect(result.promotionAmount, closeTo(10000, 0.01));
    });

    test('two BXGY AMOUNT different qualifier different reward both apply', () {
      final result = calculate(
        cartItems: [
          plain(1, 50000, name: 'A'),
          plain(2, 30000, name: 'B'),
          plain(3, 40000, name: 'C'),
          plain(4, 20000, name: 'D'),
        ],
        paymentMethod: 'CASH',
        promotions: [
          bxgy(
            id: 1,
            rewardType: 'AMOUNT',
            rewardValue: 10000,
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
          bxgy(
            id: 2,
            rewardType: 'AMOUNT',
            rewardValue: 5000,
            buyProductIds: const [3],
            rewardProductIds: const [4],
          ),
        ],
      );

      expect(result.promotionAmount, closeTo(15000, 0.01));
    });

    test('two BXGY FREE same qualifier different rewards both apply', () {
      final result = calculate(
        cartItems: [
          plain(1, 50000, name: 'A'),
          plain(2, 30000, name: 'B'),
          plain(3, 20000, name: 'C'),
        ],
        paymentMethod: 'CASH',
        promotions: [
          bxgy(
            id: 1,
            rewardType: 'FREE',
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
          bxgy(
            id: 2,
            rewardType: 'FREE',
            buyProductIds: const [1],
            rewardProductIds: const [3],
          ),
        ],
      );

      expect(result.promotionAmount, closeTo(50000, 0.01));
    });

    test('two BXGY FREE same qualifier same reward qty 2 only first applies per server behavior', () {
      // Server-confirmed: once a FREE promo spends a qualifier unit on a reward
      // scope, another promo targeting the same scope cannot reuse it -- even
      // with reward stock left. B has qty 2, but A has only one unit.
      final result = calculate(
        cartItems: [
          plain(1, 50000, name: 'A'),
          plain(2, 30000, qty: 2, name: 'B'),
        ],
        paymentMethod: 'CASH',
        promotions: [
          bxgy(
            id: 1,
            rewardType: 'FREE',
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
          bxgy(
            id: 2,
            rewardType: 'FREE',
            buyProductIds: const [1],
            rewardProductIds: const [2],
          ),
        ],
      );

      expect(result.promotionAmount, closeTo(30000, 0.01));
      expect(result.appliedPromotionIds, [1]);
    });

    test(
      'two BXGY FREE same qualifier same reward qty 1 only first applies',
      () {
        final result = calculate(
          cartItems: [
            plain(1, 50000, name: 'A'),
            plain(2, 30000, name: 'B'),
          ],
          paymentMethod: 'CASH',
          promotions: [
            bxgy(
              id: 1,
              rewardType: 'FREE',
              buyProductIds: const [1],
              rewardProductIds: const [2],
            ),
            bxgy(
              id: 2,
              rewardType: 'FREE',
              buyProductIds: const [1],
              rewardProductIds: const [2],
            ),
          ],
        );

        expect(result.promotionAmount, closeTo(30000, 0.01));
      },
    );
  });

  group('discount', () {
    test('discount AMOUNT PRODUCT scope caps total at value not per item', () {
      // Each eligible product used to take min(10000, itemSubtotal)
      // independently, which totalled 20000.
      final result = calculate(
        cartItems: [
          plain(101, 50000, cartKey: '101', name: 'Produk A'),
          plain(102, 30000, cartKey: '102', name: 'Produk B'),
        ],
        paymentMethod: 'CASH',
        discountInput: const DiscountInput(
          valueType: 'AMOUNT',
          value: 10000,
          scope: 'PRODUCT',
          eligibleProductIds: [101, 102],
        ),
      );

      expect(
        result.discountAmount,
        closeTo(10000, 0.01),
        reason: 'total discount capped at 10000',
      );
    });

    test('discount AMOUNT PRODUCT scope non-eligible item gets zero', () {
      final result = calculate(
        cartItems: [
          plain(101, 50000, cartKey: '101', name: 'Produk A'),
          plain(999, 40000, cartKey: '999', name: 'Produk lain'),
        ],
        paymentMethod: 'CASH',
        discountInput: const DiscountInput(
          valueType: 'AMOUNT',
          value: 10000,
          scope: 'PRODUCT',
          eligibleProductIds: [101],
        ),
      );

      expect(
        result.discountAmount,
        closeTo(10000, 0.01),
        reason: 'total discount still 10000 regardless of non-eligible items',
      );
    });
  });

  group('cash rounding', () {
    test('applies the payment setting rounding to a cash total only', () {
      const rounding = PaymentSetting(
        paymentSettingId: 1,
        isPriceIncludeTax: false,
        isRounding: true,
        roundingTarget: 100,
        roundingType: 'CEILING',
        isServiceCharge: false,
        serviceChargePercentage: 0,
        serviceChargeAmount: 0,
        isTax: false,
        taxPercentage: 0,
        taxName: 'none',
      );

      final cash = calculate(
        cartItems: [plain(1, 10450)],
        paymentSettings: rounding,
        paymentMethod: 'CASH',
      );
      expect(cash.totalAmount, 10500.0);
      expect(cash.rounding, 50.0);

      final card = calculate(
        cartItems: [plain(1, 10450)],
        paymentSettings: rounding,
        paymentMethod: 'CARD',
      );
      expect(card.totalAmount, 10450.0);
      expect(card.rounding, 0.0);
    });

    test('rounds a fractional cash total to whole rupiah', () {
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'Item',
            price: 18055,
            quantity: 1,
            cartKey: '1',
            isTaxable: true,
            taxId: 1,
            taxPercentage: 10,
          ),
        ],
        paymentMethod: 'CASH',
      );

      // tax = 1805.5 -> total 19860.5 -> 19861
      expect(result.tax, 1806.0);
      expect(result.totalAmount, 19861.0);
    });

    test(
      'calculateCashPaymentWithRounding reports the rounded total and delta',
      () {
        const rounding = PaymentSetting(
          paymentSettingId: 1,
          isPriceIncludeTax: false,
          isRounding: true,
          roundingTarget: 100,
          roundingType: 'FLOOR',
          isServiceCharge: false,
          serviceChargePercentage: 0,
          serviceChargeAmount: 0,
          isTax: false,
          taxPercentage: 0,
          taxName: 'none',
        );

        final cash = TransactionCalculator.calculateCashPaymentWithRounding(
          10450,
          rounding,
        );
        expect(cash.total, 10400.0);
        expect(cash.rounding, -50.0);
      },
    );
  });

  group('service charge', () {
    test('applies to subtotal plus tax, before discount', () {
      const withServiceCharge = PaymentSetting(
        paymentSettingId: 1,
        isPriceIncludeTax: false,
        isRounding: false,
        roundingTarget: 0,
        roundingType: 'NONE',
        isServiceCharge: true,
        serviceChargePercentage: 10,
        serviceChargeAmount: 0,
        isTax: true,
        taxPercentage: 10,
        taxName: 'PPN',
      );

      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'Item',
            price: 10000,
            quantity: 1,
            cartKey: '1',
            isTaxable: true,
            taxId: 1,
            taxPercentage: 10,
          ),
        ],
        paymentSettings: withServiceCharge,
        paymentMethod: 'CARD',
        discountInput: const DiscountInput(valueType: 'AMOUNT', value: 2000),
      );

      // tax base = 10000 - 2000 = 8000 -> tax 800
      // service charge = (10000 + 800) x 10% = 1080, computed before discount
      expect(result.tax, closeTo(800, 0.01));
      expect(result.serviceCharge, closeTo(1080, 0.01));
      expect(result.totalAmount, closeTo(10000 - 2000 + 800 + 1080, 0.01));
    });
  });

  group('guards', () {
    test('an empty cart totals to zero', () {
      final result = calculate(cartItems: const []);
      expect(result.subTotal, 0);
      expect(result.totalAmount, 0);
      expect(result.transactionItems, isEmpty);
    });

    test('a promotion can never exceed the amount left after the discount', () {
      final result = calculate(
        cartItems: [plain(1, 20000)],
        discountInput: const DiscountInput(valueType: 'AMOUNT', value: 2000),
        promotions: const [
          PromotionInput(
            promotionId: 1,
            promoType: 'DISCOUNT_BY_ORDER',
            priority: 1,
            canCombine: true,
            valueType: 'AMOUNT',
            value: 20000,
          ),
        ],
      );

      expect(result.discountAmount, 2000.0);
      expect(result.promotionAmount, 18000.0);
      expect(result.totalAmount, 0.0);
    });

    test('groups tax breakdowns by tax id and skips fully free lines', () {
      const a = CartItemData(
        productId: 1,
        productName: 'A',
        price: 10000,
        quantity: 1,
        cartKey: '1',
        isTaxable: true,
        taxId: 1,
        taxName: 'PPN',
        taxPercentage: 10,
        taxAmountPerUnit: 1000,
      );
      const b = CartItemData(
        productId: 2,
        productName: 'B',
        price: 20000,
        quantity: 1,
        cartKey: '2',
        isTaxable: true,
        taxId: 1,
        taxName: 'PPN',
        taxPercentage: 10,
        taxAmountPerUnit: 2000,
      );

      final result = calculate(cartItems: const [a, b]);
      expect(result.taxBreakdowns.length, 1);
      expect(result.taxBreakdowns.single.taxId, 1);
      expect(result.taxBreakdowns.single.amount, closeTo(3000, 0.01));
    });
  });

  group('getRoundedTotalAmountForDisplay', () {
    test('leaves an already-integer cash total alone', () {
      final result = calculate(
        cartItems: [plain(1, 10000)],
        paymentMethod: 'CASH',
      );
      expect(
        TransactionCalculator.getRoundedTotalAmountForDisplay(
          result,
          paymentMethod: 'CASH',
        ),
        10000.0,
      );
    });

    test('rounds a fractional non-cash total for display', () {
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'Item',
            price: 18055,
            quantity: 1,
            cartKey: '1',
            isTaxable: true,
            taxId: 1,
            taxPercentage: 10,
          ),
        ],
        paymentMethod: 'QRIS',
      );
      // 18055 + 1805.5 = 19860.5 -> displayed as 19861
      expect(
        TransactionCalculator.getRoundedTotalAmountForDisplay(result),
        19861.0,
      );
    });
  });
}
