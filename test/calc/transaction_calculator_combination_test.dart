import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/transaction_calculator.dart';
import 'package:cashup_pos/src/models/create_transaction_request.dart';
import 'package:cashup_pos/src/models/option_group.dart';
import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `TransactionCalculatorCombinationTest.kt`: variant × modifier ×
/// discount × promotion.
///
/// Sections, as in Kotlin:
///  A. Variant only
///  B. Modifier only
///  C. Variant + Modifier
///  D. Discount only (ALL / PRODUCT / CATEGORY scope)
///  E. Promotion only (DISCOUNT_BY_ORDER / BUY_X_GET_Y / DISCOUNT_BY_ITEM_SUBTOTAL)
///  F. Variant + Discount
///  G. Modifier + Discount
///  H. Variant + Modifier + Discount
///  I. Variant + Promotion
///  J. Modifier + Promotion
///  K. Variant + Modifier + Promotion
///  L. Discount + Promotion
///  M. Variant + Modifier + Discount + Promotion (full combination)
///  N. Payload shape verification for full combinations
///
/// The trailing regression tests follow section N, as they do in Kotlin.
/// Kotlin's `CartItemData.cartKey` defaults to the product id; Dart requires
/// it, so lines that omit it in Kotlin pass the product id here. The Kotlin
/// `log(...)` console dumps are not ported.
void main() {
  PaymentSetting settings({
    bool includeTax = false,
    double taxPct = 10,
    bool rounding = false,
    bool serviceCharge = false,
    double serviceChargePct = 0,
  }) => PaymentSetting(
    paymentSettingId: 1,
    isPriceIncludeTax: includeTax,
    isRounding: rounding,
    roundingTarget: rounding ? 100 : 0,
    roundingType: rounding ? 'NEAREST' : 'NONE',
    isServiceCharge: serviceCharge,
    serviceChargePercentage: serviceChargePct,
    serviceChargeAmount: 0,
    isTax: true,
    taxPercentage: taxPct,
    taxName: 'PB1',
  );

  VariantOption variant(
    int id,
    int groupId,
    String name,
    double addPrice, [
    String groupName = 'Ukuran',
  ]) => VariantOption(
    id: id,
    variantGroupId: groupId,
    name: name,
    additionalPrice: addPrice,
    groupName: groupName,
  );

  ModifierOption modifier(
    int id,
    int productId,
    String name,
    double addPrice, [
    int groupId = 1,
    String groupName = 'Topping',
  ]) => ModifierOption(
    id: id,
    productId: productId,
    name: name,
    additionalPrice: addPrice,
    groupId: groupId,
    groupName: groupName,
  );

  DiscountInput discountPercentage({
    int id = 1,
    required double value,
    double? maxCap,
    double minPurchase = 0,
    String scope = 'ALL',
    List<int> productIds = const [],
    List<int> categoryIds = const [],
  }) => DiscountInput(
    discountId: id,
    name: 'Diskon $value%',
    valueType: 'PERCENTAGE',
    value: value,
    maxDiscountAmount: maxCap,
    minPurchase: minPurchase,
    scope: scope,
    eligibleProductIds: productIds,
    eligibleCategoryIds: categoryIds,
  );

  DiscountInput discountAmount({
    int id = 1,
    required double value,
    double minPurchase = 0,
    String scope = 'ALL',
    List<int> productIds = const [],
    List<int> categoryIds = const [],
  }) => DiscountInput(
    discountId: id,
    name: 'Diskon Rp$value',
    valueType: 'AMOUNT',
    value: value,
    minPurchase: minPurchase,
    scope: scope,
    eligibleProductIds: productIds,
    eligibleCategoryIds: categoryIds,
  );

  PromotionInput promoByOrder({
    int id = 10,
    String valueType = 'AMOUNT',
    required double value,
    double minPurchase = 0,
    bool canCombine = true,
  }) => PromotionInput(
    promotionId: id,
    promoType: 'DISCOUNT_BY_ORDER',
    priority: 1,
    canCombine: canCombine,
    valueType: valueType,
    value: value,
    minPurchase: minPurchase,
  );

  PromotionInput promoBuyXGetY({
    int id = 20,
    int buyQty = 1,
    int getQty = 1,
    String rewardType = 'FREE',
    double? rewardValue,
    String buyScope = 'ALL',
    List<int> buyProductIds = const [],
    String rewardScope = 'ALL',
    List<int> rewardProductIds = const [],
    bool isMultiplied = false,
    bool canCombine = true,
    int priority = 1,
  }) => PromotionInput(
    promotionId: id,
    promoType: 'BUY_X_GET_Y',
    priority: priority,
    canCombine: canCombine,
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

  PromotionInput promoByItemSubtotal({
    int id = 30,
    String valueType = 'PERCENTAGE',
    required double value,
    double minPurchase = 0,
    bool isMultiplied = true,
    bool canCombine = true,
  }) => PromotionInput(
    promotionId: id,
    promoType: 'DISCOUNT_BY_ITEM_SUBTOTAL',
    priority: 1,
    canCombine: canCombine,
    valueType: valueType,
    value: value,
    minPurchase: minPurchase,
    isMultiplied: isMultiplied,
  );

  TransactionCalculationInput input(
    List<CartItemData> cartItems, {
    DiscountInput? discount,
    List<PromotionInput> promotions = const [],
    String paymentMethod = 'QRIS',
    bool priceIncludeTax = false,
    PaymentSetting? paymentSettings,
  }) => TransactionCalculationInput(
    cartItems: cartItems,
    paymentSettings: paymentSettings,
    paymentMethod: paymentMethod,
    priceIncludeTax: priceIncludeTax,
    discountInput: discount,
    promotions: promotions,
  );

  TransactionCalculationResult calculate(TransactionCalculationInput i) =>
      TransactionCalculator.calculateTransaction(i);

  RequestTransactionItem lineOf(CreateTransactionRequest payload, int id) =>
      payload.transactionItems.firstWhere((i) => i.productId == id);

  double subTotalOf(List<CartItemData> items) =>
      items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);

  // ─── A. Variant only ─────────────────────────────────────────────────────

  group('A. Variant only', () {
    test('variantOnly_additionalPriceAddedToEffectivePrice', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi Susu',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
        ),
      ];
      final result = calculate(input(cartItems));

      expect(result.subTotal, 30000);
      expect(result.totalAmount, 30000);
    });

    test('variantOnly_multipleVariantGroupsCombineAdditionalPrices', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi Susu',
          price: 30000,
          basePrice: 25000,
          quantity: 2,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [
            variant(2, 1, 'Large', 5000, 'Ukuran'),
            variant(5, 2, 'Hot', 0, 'Suhu'),
          ],
        ),
      ];
      final result = calculate(input(cartItems));

      expect(result.subTotal, 60000);
      expect(result.totalAmount, 60000);
    });

    test('variantOnly_zeroAdditionalPriceVariantNoEffect', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Teh Tarik',
          price: 15000,
          basePrice: 15000,
          quantity: 1,
          cartKey: '1',
          variantId: 3,
          selectedVariants: [variant(3, 1, 'Medium', 0)],
        ),
      ];
      final result = calculate(input(cartItems));

      expect(result.subTotal, 15000);
      expect(result.totalAmount, 15000);
    });
  });

  // ─── B. Modifier only ────────────────────────────────────────────────────

  group('B. Modifier only', () {
    test('modifierOnly_singleModifierAddsToTotal', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Americano',
          price: 25000,
          basePrice: 20000,
          quantity: 1,
          cartKey: '1',
          selectedModifiers: [modifier(11, 1, 'Extra Shot', 5000)],
        ),
      ];
      final result = calculate(input(cartItems));

      expect(result.subTotal, 25000);
    });

    test('modifierOnly_multipleModifiersAccumulateAdditionalPrices', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Americano',
          price: 28000,
          basePrice: 20000,
          quantity: 1,
          cartKey: '1',
          selectedModifiers: [
            modifier(11, 1, 'Extra Shot', 5000, 1, 'Espresso'),
            modifier(12, 1, 'Oat Milk', 3000, 2, 'Susu'),
          ],
        ),
      ];
      final result = calculate(input(cartItems));

      expect(result.subTotal, 28000);
      expect(result.totalAmount, 28000);
    });

    test('modifierOnly_multipleQuantityMultipliesEffectivePrice', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Americano',
          price: 28000,
          basePrice: 20000,
          quantity: 3,
          cartKey: '1',
          selectedModifiers: [
            modifier(11, 1, 'Extra Shot', 5000),
            modifier(12, 1, 'Oat Milk', 3000),
          ],
        ),
      ];
      final result = calculate(input(cartItems));

      expect(result.subTotal, 84000);
      expect(result.totalAmount, 84000);
    });
  });

  // ─── C. Variant + Modifier ───────────────────────────────────────────────

  group('C. Variant + Modifier', () {
    test('variantAndModifier_bothAdditionalPricesCombine', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi Susu',
          price: 35000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
          selectedModifiers: [modifier(11, 1, 'Extra Shot', 5000)],
        ),
      ];
      final result = calculate(input(cartItems));

      expect(result.subTotal, 35000);
      expect(result.totalAmount, 35000);
    });

    test('variantAndModifier_payloadContainsCorrectDetailsArray', () {
      final selectedVariants = [
        variant(2, 1, 'Sedang', 0, 'Level Pedas'),
        variant(6, 2, 'Paha Atas', 2000, 'Potongan Ayam'),
      ];
      final selectedModifiers = [
        modifier(11, 34, 'Tempe', 2000, 3, 'Menu Tambahan'),
      ];

      final cartItems = [
        CartItemData(
          productId: 34,
          productName: 'Pecel Ayam',
          price: 29000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '34',
          variantId: 6,
          selectedVariants: selectedVariants,
          selectedModifiers: selectedModifiers,
        ),
      ];
      final result = calculate(input(cartItems));
      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        cartItemsForBreakdown: cartItems,
      );
      final item = payload.transactionItems.single;

      expect(item.variantId, 6);
      expect(item.variantOptionIds, [2, 6]);
      expect(item.details?.length, 3);
      expect(item.details![0].detailType, 'VARIANT');
      expect(item.details![1].detailType, 'VARIANT');
      expect(item.details![2].detailType, 'MODIFIER');
      expect(item.details![0].name, 'Sedang');
      expect(item.details![1].name, 'Paha Atas');
      expect(item.details![2].name, 'Tempe');
    });
  });

  // ─── D. Discount only ────────────────────────────────────────────────────

  group('D. Discount only', () {
    test('discountOnly_percentageAllScope_appliedToSubTotal', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 100000,
          quantity: 1,
          cartKey: '1',
        ),
      ];
      final result = calculate(
        input(cartItems, discount: discountPercentage(value: 10)),
      );

      expect(result.discountAmount, 10000);
      expect(result.totalAmount, 90000);
    });

    test('discountOnly_flatAmountAllScope_deductedFromTotal', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 50000,
          quantity: 1,
          cartKey: '1',
        ),
      ];
      final result = calculate(
        input(cartItems, discount: discountAmount(value: 15000)),
      );

      expect(result.discountAmount, 15000);
      expect(result.totalAmount, 35000);
    });

    test('discountOnly_percentageWithMaxCap_cappedAtMaxDiscountAmount', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 100000,
          quantity: 1,
          cartKey: '1',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(value: 50, maxCap: 20000),
        ),
      );

      expect(result.discountAmount, 20000);
      expect(result.totalAmount, 80000);
    });

    test('discountOnly_productScope_appliesOnlyToEligibleProducts', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 40000,
          quantity: 1,
          cartKey: '1',
        ),
        CartItemData(
          productId: 2,
          productName: 'B',
          price: 60000,
          quantity: 1,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(
            value: 10,
            scope: 'PRODUCT',
            productIds: [1],
          ),
        ),
      );

      expect(result.discountAmount, 4000);
      expect(result.totalAmount, 96000);
    });

    test('discountOnly_categoryScope_appliesOnlyToEligibleCategories', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Sayur',
          price: 30000,
          quantity: 1,
          cartKey: '1',
          categoryIds: [5],
        ),
        CartItemData(
          productId: 2,
          productName: 'Daging',
          price: 70000,
          quantity: 1,
          cartKey: '2',
          categoryIds: [9],
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(
            value: 10,
            scope: 'CATEGORY',
            categoryIds: [5],
          ),
        ),
      );

      expect(result.discountAmount, 3000);
      expect(result.totalAmount, 97000);
    });

    test('discountOnly_minPurchaseNotMet_noDiscountApplied', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 30000,
          quantity: 1,
          cartKey: '1',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountAmount(value: 10000, minPurchase: 50000),
        ),
      );

      expect(result.discountAmount, 0);
      expect(result.totalAmount, 30000);
    });

    test('discountOnly_multipleItems_percentageAppliesToAllItems', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 10000,
          quantity: 1,
          cartKey: '1',
        ),
        CartItemData(
          productId: 2,
          productName: 'B',
          price: 20000,
          quantity: 1,
          cartKey: '2',
        ),
        CartItemData(
          productId: 3,
          productName: 'C',
          price: 30000,
          quantity: 1,
          cartKey: '3',
        ),
      ];
      final result = calculate(
        input(cartItems, discount: discountPercentage(value: 20)),
      );

      expect(result.discountAmount, 12000);
      expect(result.totalAmount, 48000);
    });
  });

  // ─── E. Promotion only ───────────────────────────────────────────────────

  group('E. Promotion only', () {
    test('promotionOnly_discountByOrder_flatAmountOffTotal', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 80000,
          quantity: 1,
          cartKey: '1',
        ),
      ];
      final result = calculate(
        input(cartItems, promotions: [promoByOrder(value: 20000)]),
      );

      expect(result.promotionAmount, 20000);
      expect(result.totalAmount, 60000);
    });

    test('promotionOnly_discountByOrder_percentageOffTotal', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 80000,
          quantity: 1,
          cartKey: '1',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          promotions: [promoByOrder(valueType: 'PERCENTAGE', value: 15)],
        ),
      );

      expect(result.promotionAmount, 12000);
      expect(result.totalAmount, 68000);
    });

    test('promotionOnly_buyXGetY_freeRewardIsFullPrice', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Gula',
          price: 10000,
          quantity: 1,
          cartKey: '1',
        ),
        CartItemData(
          productId: 2,
          productName: 'Prima',
          price: 8000,
          quantity: 1,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          promotions: [
            promoBuyXGetY(
              buyScope: 'PRODUCT',
              buyProductIds: [1],
              rewardScope: 'PRODUCT',
              rewardProductIds: [2],
            ),
          ],
        ),
      );

      expect(result.promotionAmount, 8000);
      expect(result.totalAmount, 10000);
    });

    test('promotionOnly_buyXGetY_percentageRewardAppliedToRewardItem', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Gula',
          price: 10000,
          quantity: 1,
          cartKey: '1',
        ),
        CartItemData(
          productId: 2,
          productName: 'Prima',
          price: 8000,
          quantity: 1,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          promotions: [
            promoBuyXGetY(
              rewardType: 'PERCENTAGE',
              rewardValue: 50,
              buyScope: 'PRODUCT',
              buyProductIds: [1],
              rewardScope: 'PRODUCT',
              rewardProductIds: [2],
            ),
          ],
        ),
      );

      expect(result.promotionAmount, 4000);
      expect(result.totalAmount, 14000);
    });

    test('promotionOnly_buyXGetY_isMultiplied_repeatsRewardPerBuyCycle', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Gula',
          price: 10000,
          quantity: 3,
          cartKey: '1',
        ),
        CartItemData(
          productId: 2,
          productName: 'Prima',
          price: 8000,
          quantity: 3,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          promotions: [
            promoBuyXGetY(
              isMultiplied: true,
              buyScope: 'PRODUCT',
              buyProductIds: [1],
              rewardScope: 'PRODUCT',
              rewardProductIds: [2],
            ),
          ],
        ),
      );

      expect(result.promotionAmount, 24000);
      expect(result.totalAmount, 30000);
    });

    test('promotionOnly_discountByItemSubtotal_percentageAppliedPerItem', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 20000,
          quantity: 1,
          cartKey: '1',
        ),
        CartItemData(
          productId: 2,
          productName: 'B',
          price: 10000,
          quantity: 1,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(cartItems, promotions: [promoByItemSubtotal(value: 10)]),
      );

      expect(result.promotionAmount, 3000);
      expect(result.totalAmount, 27000);
    });

    test('promotionOnly_discountByItemSubtotal_flatAmountNotMultiplied', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 55000,
          quantity: 2,
          cartKey: '1',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          promotions: [
            promoByItemSubtotal(
              valueType: 'AMOUNT',
              value: 20000,
              minPurchase: 100000,
              isMultiplied: false,
            ),
          ],
        ),
      );

      expect(result.promotionAmount, 20000);
      expect(result.totalAmount, 90000);
    });
  });

  // ─── F. Variant + Discount ───────────────────────────────────────────────

  group('F. Variant + Discount', () {
    test('variantAndDiscount_percentageDiscountAppliedOnEffectivePrice', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
        ),
      ];
      final result = calculate(
        input(cartItems, discount: discountPercentage(value: 10)),
      );

      expect(result.subTotal, 30000);
      expect(result.discountAmount, 3000);
      expect(result.totalAmount, 27000);
    });

    test('variantAndDiscount_flatAmountDiscountIgnoresVariantPrice', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
        ),
      ];
      final result = calculate(
        input(cartItems, discount: discountAmount(value: 8000)),
      );

      expect(result.discountAmount, 8000);
      expect(result.totalAmount, 22000);
    });

    test('variantAndDiscount_productScopeDiscount_variantPriceIncludedInEligibleSubtotal', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
        ),
        const CartItemData(
          productId: 2,
          productName: 'Teh',
          price: 20000,
          quantity: 1,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(
            value: 10,
            scope: 'PRODUCT',
            productIds: [1],
          ),
        ),
      );

      expect(result.discountAmount, 3000);
      expect(result.totalAmount, 47000);
    });
  });

  // ─── G. Modifier + Discount ──────────────────────────────────────────────

  group('G. Modifier + Discount', () {
    test('modifierAndDiscount_percentageDiscountAppliedOnEffectivePriceIncludingModifiers', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Americano',
          price: 25000,
          basePrice: 20000,
          quantity: 1,
          cartKey: '1',
          selectedModifiers: [modifier(11, 1, 'Extra Shot', 5000)],
        ),
      ];
      final result = calculate(
        input(cartItems, discount: discountPercentage(value: 20)),
      );

      expect(result.subTotal, 25000);
      expect(result.discountAmount, 5000);
      expect(result.totalAmount, 20000);
    });

    test('modifierAndDiscount_multipleModifiersWithMaxCapDiscount', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Americano',
          price: 28000,
          basePrice: 20000,
          quantity: 1,
          cartKey: '1',
          selectedModifiers: [
            modifier(11, 1, 'Extra Shot', 5000),
            modifier(12, 1, 'Oat Milk', 3000),
          ],
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(value: 50, maxCap: 10000),
        ),
      );

      expect(result.discountAmount, 10000);
      expect(result.totalAmount, 18000);
    });
  });

  // ─── H. Variant + Modifier + Discount ────────────────────────────────────

  group('H. Variant + Modifier + Discount', () {
    test(
      'variantModifierAndDiscount_effectivePriceIsBaseForDiscountCalculation',
      () {
        final cartItems = [
          CartItemData(
            productId: 1,
            productName: 'Kopi Susu',
            price: 35000,
            basePrice: 25000,
            quantity: 1,
            cartKey: '1',
            variantId: 2,
            selectedVariants: [variant(2, 1, 'Large', 5000)],
            selectedModifiers: [modifier(11, 1, 'Extra Shot', 5000)],
          ),
        ];
        final result = calculate(
          input(cartItems, discount: discountPercentage(value: 10)),
        );

        expect(result.subTotal, 35000);
        expect(result.discountAmount, 3500);
        expect(result.totalAmount, 31500);
      },
    );

    test(
      'variantModifierAndDiscount_flatDiscountDeductedFromEffectiveTotal',
      () {
        final cartItems = [
          CartItemData(
            productId: 1,
            productName: 'Kopi Susu',
            price: 35000,
            basePrice: 25000,
            quantity: 2,
            cartKey: '1',
            variantId: 2,
            selectedVariants: [variant(2, 1, 'Large', 5000)],
            selectedModifiers: [modifier(11, 1, 'Extra Shot', 5000)],
          ),
        ];
        final result = calculate(
          input(cartItems, discount: discountAmount(value: 12000)),
        );

        expect(result.subTotal, 70000);
        expect(result.discountAmount, 12000);
        expect(result.totalAmount, 58000);
      },
    );
  });

  // ─── I. Variant + Promotion ──────────────────────────────────────────────

  group('I. Variant + Promotion', () {
    test('variantAndPromotion_discountByOrderAppliedToEffectiveTotal', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
        ),
      ];
      final result = calculate(
        input(cartItems, promotions: [promoByOrder(value: 5000)]),
      );

      expect(result.promotionAmount, 5000);
      expect(result.totalAmount, 25000);
    });

    test('variantAndPromotion_buyXGetY_rewardTargetsVariantProduct', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi Large',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
        ),
        const CartItemData(
          productId: 2,
          productName: 'Air',
          price: 8000,
          quantity: 1,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          promotions: [
            promoBuyXGetY(
              buyScope: 'PRODUCT',
              buyProductIds: [1],
              rewardScope: 'PRODUCT',
              rewardProductIds: [2],
            ),
          ],
        ),
      );

      expect(result.promotionAmount, 8000);
      expect(result.totalAmount, 30000);
    });

    test('variantAndPromotion_discountByItemSubtotalUsesEffectivePrice', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
        ),
      ];
      final result = calculate(
        input(cartItems, promotions: [promoByItemSubtotal(value: 10)]),
      );

      expect(result.promotionAmount, 3000);
      expect(result.totalAmount, 27000);
    });
  });

  // ─── J. Modifier + Promotion ─────────────────────────────────────────────

  group('J. Modifier + Promotion', () {
    test('modifierAndPromotion_discountByOrderIgnoresModifierBreakdown', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Americano',
          price: 28000,
          basePrice: 20000,
          quantity: 1,
          cartKey: '1',
          selectedModifiers: [
            modifier(11, 1, 'Extra Shot', 5000),
            modifier(12, 1, 'Oat Milk', 3000),
          ],
        ),
      ];
      final result = calculate(
        input(cartItems, promotions: [promoByOrder(value: 8000)]),
      );

      expect(result.promotionAmount, 8000);
      expect(result.totalAmount, 20000);
    });

    test('modifierAndPromotion_buyXGetY_freeRewardWithModifierProduct', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Americano',
          price: 28000,
          basePrice: 20000,
          quantity: 1,
          cartKey: '1',
          selectedModifiers: [modifier(11, 1, 'Extra Shot', 8000)],
        ),
        const CartItemData(
          productId: 2,
          productName: 'Croissant',
          price: 12000,
          quantity: 1,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          promotions: [
            promoBuyXGetY(
              buyScope: 'PRODUCT',
              buyProductIds: [1],
              rewardScope: 'PRODUCT',
              rewardProductIds: [2],
            ),
          ],
        ),
      );

      expect(result.promotionAmount, 12000);
      expect(result.totalAmount, 28000);
    });
  });

  // ─── K. Variant + Modifier + Promotion ───────────────────────────────────

  group('K. Variant + Modifier + Promotion', () {
    test('variantModifierAndPromotion_discountByOrderOnFullEffectiveTotal', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi Susu',
          price: 35000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
          selectedModifiers: [modifier(11, 1, 'Extra Shot', 5000)],
        ),
        CartItemData(
          productId: 2,
          productName: 'Americano',
          price: 28000,
          basePrice: 20000,
          quantity: 1,
          cartKey: '2',
          selectedModifiers: [modifier(12, 2, 'Oat Milk', 8000)],
        ),
      ];
      final result = calculate(
        input(cartItems, promotions: [promoByOrder(value: 13000)]),
      );

      expect(result.subTotal, 63000);
      expect(result.promotionAmount, 13000);
      expect(result.totalAmount, 50000);
    });

    test('variantModifierAndPromotion_buyXGetY_percentageRewardOnVariantModifierItem', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi Susu',
          price: 35000,
          basePrice: 25000,
          quantity: 2,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
          selectedModifiers: [modifier(11, 1, 'Extra Shot', 5000)],
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          promotions: [
            promoBuyXGetY(
              rewardType: 'PERCENTAGE',
              rewardValue: 50,
              buyScope: 'PRODUCT',
              buyProductIds: [1],
              rewardScope: 'PRODUCT',
              rewardProductIds: [1],
            ),
          ],
        ),
      );

      expect(result.promotionAmount, 17500);
      expect(result.totalAmount, 52500);
    });
  });

  // ─── L. Discount + Promotion ─────────────────────────────────────────────

  group('L. Discount + Promotion', () {
    test('discountAndPromotion_bothAppliedIndependently', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'A',
          price: 100000,
          quantity: 1,
          cartKey: '1',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(value: 10),
          promotions: [promoByOrder(value: 10000)],
        ),
      );

      expect(result.discountAmount, 10000);
      expect(result.promotionAmount, 10000);
      expect(result.totalAmount, 80000);
    });

    test('discountAndPromotion_productScopeDiscountWithDiscountByItemSubtotalPromo', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'P1',
          price: 50000,
          quantity: 1,
          cartKey: '1',
        ),
        CartItemData(
          productId: 2,
          productName: 'P2',
          price: 30000,
          quantity: 1,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(
            value: 10,
            scope: 'PRODUCT',
            productIds: [1],
          ),
          promotions: [promoByItemSubtotal(value: 5)],
        ),
      );

      expect(result.discountAmount, 5000);
      expect(result.promotionAmount, 4000);
      expect(result.totalAmount, 71000);
    });

    test('discountAndPromotion_buyXGetYFreeItemNotDoubleDiscounted', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Gula',
          price: 10000,
          quantity: 1,
          cartKey: '1',
        ),
        CartItemData(
          productId: 2,
          productName: 'Prima',
          price: 8000,
          quantity: 1,
          cartKey: '2',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountAmount(value: 5000),
          promotions: [
            promoBuyXGetY(
              buyScope: 'PRODUCT',
              buyProductIds: [1],
              rewardScope: 'PRODUCT',
              rewardProductIds: [2],
            ),
          ],
        ),
      );

      expect(result.promotionAmount, greaterThan(0));
      expect(result.discountAmount, greaterThanOrEqualTo(0));
      expect(result.totalAmount, lessThan(18000));
    });

    // Regression for a production bug: BUY_X_GET_Y frees 1 of 2 reward units.
    // The server validates the discount on FULL qty, then prices the FREE
    // saving after discount.
    //
    // Cart: KWT(49000×1) + prima(8000×2); buy 1 KWT → 1 prima FREE;
    // 10% on prima (PRODUCT scope) on full qty.
    //   discount    = 8000×2×10% = 1600
    //   FREE saving = (8000−800)×1 = 7200
    //   netAmount   = 65000 − 1600 − 7200 = 56200
    test('discountAndPromotion_buyXGetYPartialFreeReward_discountAppliesOnlyToPaidUnits', () {
      const cartItems = [
        CartItemData(
          productId: 34322203648028,
          productName: 'KWT SIRAM DAGING',
          price: 49000,
          quantity: 1,
          cartKey: '34322203648028',
        ),
        CartItemData(
          productId: 34257371267886,
          productName: 'prima',
          price: 8000,
          quantity: 2,
          cartKey: '34257371267886',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(
            id: 5,
            value: 10,
            scope: 'PRODUCT',
            productIds: [34257371267886],
          ),
          promotions: [
            promoBuyXGetY(
              buyScope: 'PRODUCT',
              buyProductIds: [34322203648028],
              rewardScope: 'PRODUCT',
              rewardProductIds: [34257371267886],
            ),
          ],
        ),
      );

      expect(result.subTotal, 65000);
      expect(result.discountAmount, 1600);
      expect(result.promotionAmount, 7200);
      expect(result.totalAmount, 56200);
    });

    // Regression: the tax base must exclude the free unit with
    // priceIncludeTax.
    //
    // Cart: KWT(49000×1, 10%) + prima(8000×2, 10%); 1 prima FREE; 10% on
    // prima on full qty.
    //   KWT:   49000                  → 49000 × 10/110 = 4454.55
    //   prima: 16000 − 7200 − 1600    →  7200 × 10/110 =  654.55
    //   total tax = 5109.09
    test(
      'discountAndPromotion_buyXGetYPartialFreeReward_taxExcludesFreeUnit',
      () {
        const cartItems = [
          CartItemData(
            productId: 34322203648028,
            productName: 'KWT SIRAM DAGING',
            price: 49000,
            quantity: 1,
            isTaxable: true,
            taxId: 2,
            taxName: 'PB1',
            taxPercentage: 10,
            taxAmountPerUnit: 4454.55,
            cartKey: '34322203648028',
          ),
          CartItemData(
            productId: 34257371267886,
            productName: 'prima',
            price: 8000,
            quantity: 2,
            isTaxable: true,
            taxId: 2,
            taxName: 'PB1',
            taxPercentage: 10,
            taxAmountPerUnit: 727.27,
            cartKey: '34257371267886',
          ),
        ];
        final result = calculate(
          input(
            cartItems,
            discount: discountPercentage(
              id: 5,
              value: 10,
              scope: 'PRODUCT',
              productIds: [34257371267886],
            ),
            promotions: [
              promoBuyXGetY(
                buyScope: 'PRODUCT',
                buyProductIds: [34322203648028],
                rewardScope: 'PRODUCT',
                rewardProductIds: [34257371267886],
              ),
            ],
            priceIncludeTax: true,
            paymentSettings: settings(includeTax: true),
          ),
        );

        expect(result.subTotal, 65000);
        expect(result.discountAmount, 1600);
        expect(result.promotionAmount, 7200);
        expect(result.totalAmount, 56200);
        expect(result.tax, 5109.09);
      },
    );

    // Regression: two BUY_X_GET_Y promos (PERCENTAGE + AMOUNT) target the
    // same single prima unit. The server applies only the first, so reward
    // units are claimed for every BUY_X_GET_Y type, not just FREE.
    test('discountAndPromotion_twoBuyXGetYPromosSameRewardUnit_onlyFirstPromoApplied', () {
      const cartItems = [
        CartItemData(
          productId: 34322203648028,
          productName: 'KWT SIRAM DAGING',
          price: 49000,
          quantity: 1,
          cartKey: '34322203648028',
        ),
        CartItemData(
          productId: 34257371267886,
          productName: 'prima',
          price: 8000,
          quantity: 1,
          cartKey: '34257371267886',
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          promotions: [
            promoBuyXGetY(
              id: 21,
              rewardType: 'PERCENTAGE',
              rewardValue: 10,
              buyScope: 'PRODUCT',
              buyProductIds: [34322203648028],
              rewardScope: 'PRODUCT',
              rewardProductIds: [34257371267886],
            ),
            promoBuyXGetY(
              id: 22,
              rewardType: 'AMOUNT',
              rewardValue: 5000,
              buyScope: 'PRODUCT',
              buyProductIds: [34322203648028],
              rewardScope: 'PRODUCT',
              rewardProductIds: [34257371267886],
            ),
          ],
        ),
      );

      expect(result.subTotal, 57000);
      expect(result.promotionAmount, 800);
      expect(result.totalAmount, 56200);
      expect(result.appliedPromotionIds, [21]);
    });

    // Server-confirmed regression (server 8000, client sent 8800): the FREE
    // promo consumes the KWT qualifier for its prima reward scope, so the
    // PERCENTAGE promo on the same scope is blocked even with a prima left.
    test(
      'buyXGetY_freePromoConsumesQualifier_sameRewardScopePromoIsBlocked',
      () {
        const cartItems = [
          CartItemData(
            productId: 34322203648028,
            productName: 'KWT SIRAM DAGING',
            price: 49000,
            quantity: 1,
            cartKey: '34322203648028',
          ),
          CartItemData(
            productId: 34257371267886,
            productName: 'prima',
            price: 8000,
            quantity: 2,
            cartKey: '34257371267886',
          ),
        ];
        final result = calculate(
          input(
            cartItems,
            promotions: [
              promoBuyXGetY(
                buyScope: 'PRODUCT',
                buyProductIds: [34322203648028],
                rewardScope: 'PRODUCT',
                rewardProductIds: [34257371267886],
              ),
              promoBuyXGetY(
                id: 21,
                rewardType: 'PERCENTAGE',
                rewardValue: 10,
                buyScope: 'PRODUCT',
                buyProductIds: [34322203648028],
                rewardScope: 'PRODUCT',
                rewardProductIds: [34257371267886],
              ),
            ],
          ),
        );

        expect(result.subTotal, 65000);
        expect(result.promotionAmount, 8000);
        expect(result.totalAmount, 57000);
        expect(result.appliedPromotionIds, [20]);
      },
    );

    // Two BUY_X_GET_Y promos share the SAME single KWT qualifier unit, with
    // two prima reward units available. Qualifier units are consumed for all
    // reward types — confirmed against a production BE rejection — so promo
    // 21 (applied first) spends it and promo 22 cannot apply.
    test(
      'discountAndPromotion_twoBuyXGetYPromosSharedQualifier_onlyFirstApplies',
      () {
        const cartItems = [
          CartItemData(
            productId: 34322203648028,
            productName: 'KWT SIRAM DAGING',
            price: 49000,
            quantity: 1,
            cartKey: '34322203648028',
          ),
          CartItemData(
            productId: 34257371267886,
            productName: 'prima',
            price: 8000,
            quantity: 2,
            cartKey: '34257371267886',
          ),
        ];
        final result = calculate(
          input(
            cartItems,
            promotions: [
              promoBuyXGetY(
                id: 21,
                rewardType: 'PERCENTAGE',
                rewardValue: 10,
                buyScope: 'PRODUCT',
                buyProductIds: [34322203648028],
                rewardScope: 'PRODUCT',
                rewardProductIds: [34257371267886],
              ),
              promoBuyXGetY(
                id: 22,
                rewardType: 'AMOUNT',
                rewardValue: 5000,
                buyScope: 'PRODUCT',
                buyProductIds: [34322203648028],
                rewardScope: 'PRODUCT',
                rewardProductIds: [34257371267886],
              ),
            ],
          ),
        );

        expect(result.subTotal, 65000);
        expect(result.promotionAmount, 800);
        expect(result.totalAmount, 64200);
        expect(result.appliedPromotionIds, [21]);
      },
    );
  });

  // ─── M. Full combination ─────────────────────────────────────────────────

  group('M. Variant + Modifier + Discount + Promotion', () {
    test(
      'fullCombination_variantModifierDiscountAndPromotion_correctTotals',
      () {
        final cartItems = [
          CartItemData(
            productId: 1,
            productName: 'Kopi Susu',
            price: 35000,
            basePrice: 25000,
            quantity: 2,
            cartKey: '1',
            variantId: 2,
            selectedVariants: [variant(2, 1, 'Large', 5000)],
            selectedModifiers: [modifier(11, 1, 'Extra Shot', 5000)],
          ),
        ];
        final result = calculate(
          input(
            cartItems,
            discount: discountPercentage(value: 10),
            promotions: [promoByOrder(value: 10000)],
          ),
        );

        expect(result.subTotal, 70000);
        expect(result.discountAmount, 7000);
        expect(result.promotionAmount, 10000);
        expect(result.totalAmount, 53000);
      },
    );

    test(
      'fullCombination_variantModifierDiscountAndBuyXGetYPromo_correctTotals',
      () {
        final cartItems = [
          CartItemData(
            productId: 1,
            productName: 'Kopi Susu',
            price: 35000,
            basePrice: 25000,
            quantity: 1,
            cartKey: '1',
            variantId: 2,
            selectedVariants: [variant(2, 1, 'Large', 5000)],
            selectedModifiers: [modifier(11, 1, 'Extra Shot', 5000)],
          ),
          const CartItemData(
            productId: 2,
            productName: 'Air',
            price: 8000,
            quantity: 1,
            cartKey: '2',
          ),
        ];
        final result = calculate(
          input(
            cartItems,
            discount: discountPercentage(value: 10),
            promotions: [
              promoBuyXGetY(
                buyScope: 'PRODUCT',
                buyProductIds: [1],
                rewardScope: 'PRODUCT',
                rewardProductIds: [2],
              ),
            ],
          ),
        );

        expect(result.subTotal, 43000);
        // Discount on full qty ALL: Kopi 3500 + Air 800.
        expect(result.discountAmount, 4300);
        // FREE saving at the post-discount price: 8000 − 800.
        expect(result.promotionAmount, 7200);
        expect(result.totalAmount, 31500);
      },
    );

    test('fullCombination_multipleItemsVariantModifierCategoryDiscountAndItemSubtotalPromo', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
          categoryIds: const [5],
        ),
        CartItemData(
          productId: 2,
          productName: 'Roti',
          price: 22000,
          basePrice: 20000,
          quantity: 1,
          cartKey: '2',
          selectedModifiers: [modifier(11, 2, 'Butter', 2000)],
          categoryIds: const [9],
        ),
      ];
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(
            value: 10,
            scope: 'CATEGORY',
            categoryIds: [5],
          ),
          promotions: [promoByItemSubtotal(value: 5)],
        ),
      );

      expect(result.subTotal, 52000);
      expect(result.discountAmount, 3000);
      expect(result.promotionAmount, 2600);
      expect(result.totalAmount, 46400);
    });

    test('fullCombination_withTax_discountAndPromotionReduceTaxBase', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          isTaxable: true,
          taxId: 1,
          taxName: 'PPN',
          taxPercentage: 10,
          taxAmountPerUnit: 3000,
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
        ),
      ];
      final result = calculate(
        TransactionCalculationInput(
          cartItems: cartItems,
          paymentSettings: settings(includeTax: false, taxPct: 10),
          paymentMethod: 'QRIS',
          priceIncludeTax: false,
          promotions: [promoByItemSubtotal(value: 10)],
        ),
      );

      expect(result.promotionAmount, 3000);
      expect(result.tax, closeTo(2700, 0.01));
      expect(result.totalAmount, closeTo(30000 - 3000 + 2700, 0.01));
    });

    test('fullCombination_withServiceCharge_addedAfterAllDeductions', () {
      const cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Set Menu',
          price: 100000,
          quantity: 1,
          cartKey: '1',
        ),
      ];
      final result = calculate(
        TransactionCalculationInput(
          cartItems: cartItems,
          paymentSettings: settings(serviceCharge: true, serviceChargePct: 5),
          paymentMethod: 'CASH',
          priceIncludeTax: false,
          discountInput: discountPercentage(value: 10),
          promotions: [promoByOrder(value: 5000)],
        ),
      );

      expect(result.discountAmount, 10000);
      expect(result.promotionAmount, 5000);
      expect(result.serviceCharge, greaterThan(0));
      expect(result.totalAmount, greaterThan(85000));
    });
  });

  // ─── N. Payload shape ────────────────────────────────────────────────────

  group('N. Payload shape', () {
    test(
      'payloadShape_variantModifierDiscountAndPromotion_breakdownIsComplete',
      () {
        final selectedVariants = [variant(2, 1, 'Large', 5000, 'Ukuran')];
        final selectedModifiers = [
          modifier(11, 1, 'Extra Shot', 5000, 1, 'Espresso'),
        ];

        final cartItems = [
          CartItemData(
            productId: 1,
            productName: 'Kopi Susu',
            price: 35000,
            basePrice: 25000,
            quantity: 1,
            cartKey: '1',
            variantId: 2,
            selectedVariants: selectedVariants,
            selectedModifiers: selectedModifiers,
          ),
        ];
        final promoInput = promoByOrder(id: 5, value: 5000);
        final result = calculate(
          input(
            cartItems,
            discount: discountAmount(id: 3, value: 5000),
            promotions: [promoInput],
          ),
        );
        final payload = TransactionCalculator.buildTransactionPayload(
          result: result,
          paymentMethod: 'QRIS',
          appliedPromotions: [promoInput],
          promotionIds: [5],
          cartItemsForBreakdown: cartItems,
        );
        final item = payload.transactionItems.single;

        expect(item.productName, 'Kopi Susu');
        expect(item.price, '25000.00');
        expect(item.details?.length, 2);
        expect(item.details![0].detailType, 'VARIANT');
        expect(item.details![1].detailType, 'MODIFIER');
        expect(item.promotions, isNotNull);
        expect(item.promotions!, isNotEmpty);
      },
    );

    test('payloadShape_multipleItemsWithVariantModifierPromoDiscount_allItemsHaveBreakdown', () {
      final cartItems = [
        CartItemData(
          productId: 1,
          productName: 'Kopi',
          price: 30000,
          basePrice: 25000,
          quantity: 1,
          cartKey: '1',
          variantId: 2,
          selectedVariants: [variant(2, 1, 'Large', 5000)],
        ),
        CartItemData(
          productId: 2,
          productName: 'Roti',
          price: 22000,
          basePrice: 20000,
          quantity: 1,
          cartKey: '2',
          selectedModifiers: [modifier(11, 2, 'Butter', 2000)],
        ),
      ];
      final promoInput = promoByItemSubtotal(id: 9, value: 10);
      final result = calculate(
        input(
          cartItems,
          discount: discountPercentage(value: 5),
          promotions: [promoInput],
        ),
      );
      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        appliedPromotions: [promoInput],
        promotionIds: [9],
        cartItemsForBreakdown: cartItems,
      );

      expect(payload.transactionItems.length, 2);

      final kopiItem = lineOf(payload, 1);
      expect(kopiItem.details?.length, 1);
      expect(kopiItem.details!.single.detailType, 'VARIANT');

      final rotiItem = lineOf(payload, 2);
      expect(rotiItem.details?.length, 1);
      expect(rotiItem.details!.single.detailType, 'MODIFIER');

      expect(kopiItem.promotions, isNotNull);
      expect(rotiItem.promotions, isNotNull);
    });
  });

  // ─── Regressions ─────────────────────────────────────────────────────────

  group('regressions', () {
    test(
      'buyXGetY_fixedPrice_rewardBelowFixedPrice_isNotEligibleAndDoesNotApply',
      () {
        const kwtId = 34322203648028;
        const capucinnoId = 34808446499093;
        const primaId = 34257371267886;
        const cartItems = [
          CartItemData(
            productId: kwtId,
            productName: 'KWT SIRAM DAGING',
            price: 49000,
            basePrice: 49000,
            quantity: 1,
            cartKey: 'kwt-1',
          ),
          CartItemData(
            productId: capucinnoId,
            productName: 'Capucinno',
            price: 20000,
            basePrice: 20000,
            quantity: 1,
            cartKey: 'capucinno-1',
          ),
          CartItemData(
            productId: primaId,
            productName: 'prima',
            price: 8000,
            basePrice: 8000,
            quantity: 1,
            cartKey: 'prima-1',
          ),
        ];
        const promo = PromotionInput(
          promotionId: 23,
          name: 'Buy X get Y (fixed price)',
          promoType: 'BUY_X_GET_Y',
          priority: 1,
          canCombine: true,
          buyQty: 1,
          getQty: 2,
          rewardType: 'FIXED_PRICE',
          rewardValue: 9000,
          buyScope: 'PRODUCT',
          buyProductIds: [kwtId],
          rewardScope: 'PRODUCT',
          rewardProductIds: [capucinnoId, primaId],
          selectedRewardQtyMap: {'capucinno-1': 1, 'prima-1': 1},
        );

        expect(
          TransactionCalculator.isPromotionEligible(
            promo,
            cartItems,
            subTotalOf(cartItems),
          ),
          isFalse,
        );

        final result = calculate(
          input(cartItems, promotions: [promo], paymentMethod: 'GOFOOD'),
        );

        expect(result.subTotal, 77000);
        expect(result.promotionAmount, 0);
        expect(result.totalAmount, 77000);
        expect(result.appliedPromotionIds, isEmpty);

        final uiSavings = TransactionCalculator.computePerItemSavings(
          cartItems,
          null,
          [promo],
        );
        expect(
          uiSavings.savings.values.fold<double>(0, (sum, s) => sum + s),
          closeTo(0, 0.01),
        );
      },
    );

    test('buyXGetY_fixedPrice_twoRewardItems_matchesServerAndUiBreakdown', () {
      const kwtId = 34322203648028;
      const capucinnoId = 34808446499093;
      const minyakId = 33382134135969;
      const cartItems = [
        CartItemData(
          productId: kwtId,
          productName: 'KWT SIRAM DAGING',
          price: 49000,
          basePrice: 49000,
          quantity: 1,
          cartKey: 'kwt-1',
          variantId: 619,
        ),
        CartItemData(
          productId: capucinnoId,
          productName: 'Capucinno',
          price: 20000,
          basePrice: 20000,
          quantity: 1,
          cartKey: 'capucinno-1',
        ),
        CartItemData(
          productId: minyakId,
          productName: 'Minyak goreng',
          price: 21000,
          basePrice: 21000,
          quantity: 1,
          cartKey: 'minyak-1',
        ),
      ];
      const promo = PromotionInput(
        promotionId: 23,
        name: 'Buy X get Y (fixed price)',
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        buyQty: 1,
        getQty: 2,
        rewardType: 'FIXED_PRICE',
        rewardValue: 9000,
        buyScope: 'PRODUCT',
        buyProductIds: [kwtId],
        rewardScope: 'PRODUCT',
        rewardProductIds: [minyakId, capucinnoId],
        selectedRewardQtyMap: {'capucinno-1': 1, 'minyak-1': 1},
      );

      final result = calculate(
        input(cartItems, promotions: [promo], paymentMethod: 'GOFOOD'),
      );

      expect(result.subTotal, 90000);
      expect(result.promotionAmount, 23000);
      expect(result.totalAmount, 67000);

      final uiSavings = TransactionCalculator.computePerItemSavings(
        cartItems,
        null,
        [promo],
      );
      expect(uiSavings.savings['kwt-1'] ?? 0, closeTo(0, 0.01));
      expect(uiSavings.savings['capucinno-1'] ?? 0, closeTo(11000, 0.01));
      expect(uiSavings.savings['minyak-1'] ?? 0, closeTo(12000, 0.01));

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'GOFOOD',
        priceIncludeTax: false,
        appliedPromotions: [promo],
        cartItemsForBreakdown: cartItems,
      );
      final capucinnoPromo = lineOf(payload, capucinnoId).promotions!.single;
      final minyakPromo = lineOf(payload, minyakId).promotions!.single;
      expect(capucinnoPromo.meta?.role, 'REWARD');
      expect(capucinnoPromo.amt, '11000.00');
      expect(minyakPromo.meta?.role, 'REWARD');
      expect(minyakPromo.amt, '12000.00');
    });

    // Regression: SHOPEEFOOD payload — KWT(49000) as REWARD, prima(8000) as
    // QUALIFIER. Buy 1 (any) → KWT at 7500, saving 41500.
    test(
      'buyXGetY_fixedPrice_qualifierItemHasAnnotation_shopeefoodScenario',
      () {
        const kwtId = 34322203648028;
        const primaId = 34257371267886;
        const cartItems = [
          CartItemData(
            productId: kwtId,
            productName: 'KWT SIRAM DAGING',
            price: 49000,
            basePrice: 49000,
            quantity: 1,
            cartKey: 'kwt-1',
            variantId: 619,
          ),
          CartItemData(
            productId: primaId,
            productName: 'prima',
            price: 8000,
            basePrice: 8000,
            quantity: 1,
            cartKey: 'prima-1',
          ),
        ];
        // buyScope=ALL: the server does not restrict which item qualifies, so
        // KWT is in both the buy and reward sets. Treating it as overlapping
        // and reserving its only unit would leave no reward and no annotations.
        const promo = PromotionInput(
          promotionId: 23,
          promoType: 'BUY_X_GET_Y',
          priority: 1,
          canCombine: true,
          buyQty: 1,
          getQty: 1,
          rewardType: 'FIXED_PRICE',
          rewardValue: 7500,
          buyScope: 'ALL',
          rewardScope: 'PRODUCT',
          rewardProductIds: [kwtId],
        );
        final result = calculate(
          input(cartItems, promotions: [promo], priceIncludeTax: true),
        );
        expect(result.subTotal, 57000);
        expect(result.promotionAmount, 41500);
        expect(result.totalAmount, 15500);
        expect(result.appliedPromotionIds, [23]);

        final payload = TransactionCalculator.buildTransactionPayload(
          result: result,
          paymentMethod: 'SHOPEEFOOD',
          priceIncludeTax: true,
          appliedPromotions: [promo],
          cartItemsForBreakdown: cartItems,
        );

        final kwtItem = lineOf(payload, kwtId);
        final primaItem = lineOf(payload, primaId);

        expect(kwtItem.promotions, isNotNull);
        expect(kwtItem.promotions!.single.meta?.role, 'REWARD');

        expect(primaItem.promotions, isNotNull);
        expect(primaItem.promotions!.single.meta?.role, 'QUALIFIER');
      },
    );

    // Regression: buy [KWT], reward [prima, KWT], the user selected KWT as
    // the reward. KWT is the sole qualifier, so the selection is invalid and
    // prima is rewarded instead (8000 − 7500 = 500). "No reward without a
    // qualifier."
    test('buyXGetY_fixedPrice_selfReferential_kwtSelectedAsReward_fallsBackToPrima', () {
      const kwtId = 34322203648028;
      const primaId = 34257371267886;
      const kwtCartKey = 'kwt-1';
      const cartItems = [
        CartItemData(
          productId: kwtId,
          productName: 'KWT SIRAM DAGING',
          price: 49000,
          basePrice: 49000,
          quantity: 1,
          cartKey: kwtCartKey,
          variantId: 619,
        ),
        CartItemData(
          productId: primaId,
          productName: 'prima',
          price: 8000,
          basePrice: 8000,
          quantity: 1,
          cartKey: 'prima-1',
        ),
      ];
      const promo = PromotionInput(
        promotionId: 23,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        buyQty: 1,
        getQty: 1,
        rewardType: 'FIXED_PRICE',
        rewardValue: 7500,
        buyScope: 'PRODUCT',
        buyProductIds: [kwtId],
        rewardScope: 'PRODUCT',
        rewardProductIds: [primaId, kwtId],
        selectedRewardQtyMap: {kwtCartKey: 1},
      );
      final result = calculate(
        input(cartItems, promotions: [promo], priceIncludeTax: true),
      );
      expect(result.subTotal, 57000);
      expect(result.promotionAmount, 500);
      expect(result.totalAmount, 56500);
      expect(result.appliedPromotionIds, [23]);

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'SHOPEEFOOD',
        priceIncludeTax: true,
        appliedPromotions: [promo],
        cartItemsForBreakdown: cartItems,
      );

      final kwtItem = lineOf(payload, kwtId);
      final primaItem = lineOf(payload, primaId);

      expect(kwtItem.promotions, isNotNull);
      expect(kwtItem.promotions!.single.meta?.role, 'QUALIFIER');

      expect(primaItem.promotions, isNotNull);
      expect(primaItem.promotions!.single.meta?.role, 'REWARD');
    });

    test('discountAmountAllAndBuyXGetY_fixedPrice_usesRawDiscountShareForPromotionBasis', () {
      const kwtId = 34322203648028;
      const primaId = 34257371267886;
      const capucinnoId = 34808446499093;
      const minyakId = 33382134135969;
      const cartItems = [
        CartItemData(
          productId: primaId,
          productName: 'prima',
          price: 8000,
          basePrice: 8000,
          quantity: 1,
          cartKey: 'prima-1',
        ),
        CartItemData(
          productId: capucinnoId,
          productName: 'Capucinno',
          price: 20000,
          basePrice: 20000,
          quantity: 1,
          cartKey: 'capucinno-1',
        ),
        CartItemData(
          productId: minyakId,
          productName: 'Minyak goreng',
          price: 21000,
          basePrice: 21000,
          quantity: 1,
          cartKey: 'minyak-1',
        ),
        CartItemData(
          productId: kwtId,
          productName: 'KWT SIRAM DAGING',
          price: 49000,
          basePrice: 49000,
          quantity: 1,
          cartKey: 'kwt-1',
          variantId: 619,
        ),
      ];
      final discount = discountAmount(id: 7, value: 15000);
      const promo = PromotionInput(
        promotionId: 23,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        buyQty: 1,
        getQty: 2,
        rewardType: 'FIXED_PRICE',
        rewardValue: 8000,
        buyScope: 'PRODUCT',
        buyProductIds: [kwtId],
        rewardScope: 'PRODUCT',
        rewardProductIds: [minyakId, primaId, capucinnoId],
        selectedRewardQtyMap: {'capucinno-1': 1, 'minyak-1': 1},
      );

      final result = calculate(
        input(
          cartItems,
          discount: discount,
          promotions: [promo],
          paymentMethod: 'SHOPEEFOOD',
        ),
      );

      expect(result.subTotal, 98000);
      expect(result.discountAmount, 15000);
      expect(result.promotionAmount, closeTo(18724.4897959184, 0.0001));
      expect(result.totalAmount, closeTo(64275.5102040816, 0.0001));

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'SHOPEEFOOD',
        cashTendered: '64275.51',
        priceIncludeTax: false,
        discountInput: discount,
        discountId: 7,
        appliedPromotions: [promo],
        cartItemsForBreakdown: cartItems,
      );

      expect(payload.promotionAmount, '18724.49');
      expect(payload.totalAmount, '64275.51');
      expect(payload.cashTendered, '64275.51');

      final capucinnoItem = lineOf(payload, capucinnoId);
      final minyakItem = lineOf(payload, minyakId);
      final primaItem = lineOf(payload, primaId);
      expect(capucinnoItem.discounts!.single.amt, '3061.00');
      expect(minyakItem.discounts!.single.amt, '3214.00');
      expect(primaItem.discounts!.single.amt, '1224.00');
      expect(capucinnoItem.promotions!.single.amt, '8938.78');
      expect(minyakItem.promotions!.single.amt, '9785.71');
    });

    // Production case: BUY_X_GET_Y FREE takes the reward out of the order
    // subtotal BEFORE DISCOUNT_BY_ORDER's percentage applies. The per-item
    // breakdown once recomputed DISCOUNT_BY_ORDER against the original
    // subtotal, so it summed differently from promotionAmount and the BE
    // rejected it with "Total promotion mismatch".
    test('buyXGetYFree_thenDiscountByOrderPercentage_perItemBreakdownSumsToSequentialTotal', () {
      const rewardId = 1;
      const qualifierId = 2;
      const otherId = 3;
      const cartItems = [
        CartItemData(
          productId: rewardId,
          productName: 'Reward',
          price: 10000,
          quantity: 1,
          cartKey: 'reward-1',
        ),
        CartItemData(
          productId: qualifierId,
          productName: 'Qualifier',
          price: 5000,
          quantity: 1,
          cartKey: 'qualifier-1',
        ),
        CartItemData(
          productId: otherId,
          productName: 'Other',
          price: 20000,
          quantity: 1,
          cartKey: 'other-1',
        ),
      ];
      final freePromo = promoBuyXGetY(
        buyScope: 'PRODUCT',
        buyProductIds: [qualifierId],
        rewardScope: 'PRODUCT',
        rewardProductIds: [rewardId],
      );
      final orderPromo = promoByOrder(
        id: 24,
        valueType: 'PERCENTAGE',
        value: 10,
      );

      final result = calculate(
        input(
          cartItems,
          promotions: [freePromo, orderPromo],
          paymentMethod: 'CASH',
        ),
      );

      // FREE = 10000. DISCOUNT_BY_ORDER 10% then applies to what is left:
      // (35000 − 10000) × 10% = 2500. Total 12500.
      expect(
        result.promotionAmount,
        closeTo(12500, 0.01),
        reason: 'BXGY FREE + sequential DISCOUNT_BY_ORDER',
      );

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'CASH',
        priceIncludeTax: false,
        appliedPromotions: [freePromo, orderPromo],
        cartItemsForBreakdown: cartItems,
      );

      final orderPromoAmtSum = payload.transactionItems
          .map(
            (i) => i.promotions
                ?.firstWhereOrNull((p) => p.type == 'DISCOUNT_BY_ORDER')
                ?.amt,
          )
          .nonNulls
          .fold<double>(0, (sum, amt) => sum + double.parse(amt));
      // The same 2500 as the header, not the 3500 the original 35000
      // subtotal would give.
      expect(
        orderPromoAmtSum,
        closeTo(2500, 0.01),
        reason: 'per-item DISCOUNT_BY_ORDER sum matches sequential total',
      );
    });

    // Production mismatch: a FREE reward is worth its post-discount (net)
    // price, not gross, when an AMOUNT discount is active. Gross made
    // DISCOUNT_BY_ORDER's sequential base drift by exactly the discount's
    // share of the reward's gross price.
    test('buyXGetYFree_withAmountDiscount_thenDiscountByOrderPercentage_rewardUsesNetPrice', () {
      const rewardId = 1;
      const qualifierId = 2;
      const otherId = 3;
      const cartItems = [
        CartItemData(
          productId: rewardId,
          productName: 'Reward',
          price: 10000,
          quantity: 1,
          cartKey: 'reward-1',
        ),
        CartItemData(
          productId: qualifierId,
          productName: 'Qualifier',
          price: 5000,
          quantity: 1,
          cartKey: 'qualifier-1',
        ),
        CartItemData(
          productId: otherId,
          productName: 'Other',
          price: 20000,
          quantity: 1,
          cartKey: 'other-1',
        ),
      ];
      final discount = discountAmount(id: 6, value: 3000);
      final freePromo = promoBuyXGetY(
        buyScope: 'PRODUCT',
        buyProductIds: [qualifierId],
        rewardScope: 'PRODUCT',
        rewardProductIds: [rewardId],
      );
      final orderPromo = promoByOrder(
        id: 24,
        valueType: 'PERCENTAGE',
        value: 10,
      );

      final result = calculate(
        input(
          cartItems,
          discount: discount,
          promotions: [freePromo, orderPromo],
          paymentMethod: 'CASH',
        ),
      );

      // discountShare(reward) = 3000 × 10000/35000 = 857.142857
      // FREE = 10000 − 857.142857 = 9142.857143 (net price)
      // ORDER base = 35000 − 10000 (gross) = 25000; minus discount = 22000
      // ORDER = 2200; total = 11342.857143
      expect(result.promotionAmount, closeTo(11342.857143, 0.01));
    });

    test('discountAmountAllAndBuyXGetY_percentage_usesRoundedDiscountShareForPromotionBasis', () {
      const kwtId = 34322203648028;
      const primaId = 34257371267886;
      const capucinnoId = 34808446499093;
      const minyakId = 33382134135969;
      const cartItems = [
        CartItemData(
          productId: kwtId,
          productName: 'KWT SIRAM DAGING',
          price: 49000,
          basePrice: 49000,
          quantity: 1,
          cartKey: 'kwt-1',
          categoryIds: [6217366856903],
          variantId: 619,
        ),
        CartItemData(
          productId: primaId,
          productName: 'prima',
          price: 8000,
          basePrice: 8000,
          quantity: 1,
          cartKey: 'prima-1',
          categoryIds: [6217366856903],
        ),
        CartItemData(
          productId: capucinnoId,
          productName: 'Capucinno',
          price: 20000,
          basePrice: 20000,
          quantity: 1,
          cartKey: 'capucinno-1',
          categoryIds: [6217366856903],
        ),
        CartItemData(
          productId: minyakId,
          productName: 'Minyak goreng',
          price: 21000,
          basePrice: 21000,
          quantity: 1,
          cartKey: 'minyak-1',
          categoryIds: [5795956385980],
        ),
      ];
      final discount = discountAmount(id: 7, value: 15000);
      const promo = PromotionInput(
        promotionId: 21,
        name: 'buy X get Y (%)',
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        buyQty: 1,
        getQty: 2,
        rewardType: 'PERCENTAGE',
        rewardValue: 10,
        buyScope: 'PRODUCT',
        buyProductIds: [kwtId, primaId, capucinnoId, minyakId],
        rewardScope: 'CATEGORY',
        rewardCategoryIds: [
          5763540195909,
          5795956385980,
          5828372576051,
          6217366856903,
        ],
        selectedRewardQtyMap: {'capucinno-1': 1, 'minyak-1': 1},
      );

      final result = calculate(
        input(
          cartItems,
          discount: discount,
          promotions: [promo],
          paymentMethod: 'GRABFOOD',
        ),
      );

      expect(result.subTotal, 98000);
      expect(result.discountAmount, 15000);
      expect(result.promotionAmount, 3473);
      expect(result.totalAmount, 79527);

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'GRABFOOD',
        cashTendered: '79527.00',
        priceIncludeTax: false,
        discountInput: discount,
        discountId: 7,
        appliedPromotions: [promo],
        cartItemsForBreakdown: cartItems,
      );

      expect(payload.promotionAmount, '3473.00');
      expect(payload.totalAmount, '79527.00');
      expect(lineOf(payload, capucinnoId).promotions!.single.amt, '1694.14');
      expect(lineOf(payload, minyakId).promotions!.single.amt, '1778.86');
    });

    // Exact server case: product adj 2 (14000 × 2) + KWT (49000 × 1), 20%
    // ALL, FREE buy 1 KWT get 1 adj 2. Server: discount 15400, promo 11200,
    // netAmount 50400.
    test('buyXGetY_free_with_percentage_discount_uses_full_qty_for_discount_and_post_discount_for_promo_saving', () {
      const productAdj2Id = 35229856970016;
      const kwtId = 34192538887744;
      const productAdj2 = CartItemData(
        productId: productAdj2Id,
        productName: 'Product adjustable 2',
        price: 14000,
        quantity: 2,
        cartKey: 'adj2',
      );
      const kwt = CartItemData(
        productId: kwtId,
        productName: 'KWT GOR DAGING',
        price: 49000,
        quantity: 1,
        cartKey: 'kwt',
      );
      const discount = DiscountInput(
        discountId: 5,
        valueType: 'PERCENTAGE',
        value: 20,
      );
      const promo = PromotionInput(
        promotionId: 20,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'FREE',
        buyQty: 1,
        getQty: 1,
        buyScope: 'PRODUCT',
        buyProductIds: [kwtId],
        rewardScope: 'PRODUCT',
        rewardProductIds: [productAdj2Id],
      );
      final result = calculate(
        const TransactionCalculationInput(
          cartItems: [productAdj2, kwt],
          paymentSettings: null,
          paymentMethod: 'GRABFOOD',
          discountInput: discount,
          promotions: [promo],
        ),
      );

      // (14000×2×20%) + (49000×20%) = 5600 + 9800
      expect(result.discountAmount, closeTo(15400, 0.01));
      // 14000 × (1 − 0.20) × 1
      expect(result.promotionAmount, closeTo(11200, 0.01));
      // 77000 − 15400 − 11200
      expect(result.totalAmount, closeTo(50400, 0.01));
    });

    // KWT 49000 + Product Adj 2 140000 (fully free), AMOUNT 15000 ALL. The
    // FREE reward is worth its net price whatever the discount type —
    // confirmed against a production BE mismatch.
    //   discountShare = 15000 × 140000/189000 = 11111.111111
    //   promo         = 140000 − 11111.111111 = 128888.888889
    //   totalAmount   = 189000 − 15000 − 128888.888889 = 45111.111111
    test('buyXGetY_free_with_amount_discount_fully_free_item_uses_postDiscount_netPrice', () {
      const kwtId = 34322203648028;
      const prodAdj2Id = 35229856970016;
      const kwt = CartItemData(
        productId: kwtId,
        productName: 'KWT SIRAM DAGING',
        price: 49000,
        quantity: 1,
        cartKey: 'kwt',
        categoryIds: [6217366856903],
      );
      const prodAdj2 = CartItemData(
        productId: prodAdj2Id,
        productName: 'Product adjustable 2',
        price: 140000,
        quantity: 1,
        cartKey: 'adj2',
        categoryIds: [6217366856903],
      );
      const discount = DiscountInput(
        discountId: 7,
        valueType: 'AMOUNT',
        value: 15000,
      );
      const promo = PromotionInput(
        promotionId: 20,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'FREE',
        buyQty: 1,
        getQty: 1,
        buyScope: 'CATEGORY',
        buyCategoryIds: [6217366856903],
        rewardScope: 'PRODUCT',
        rewardProductIds: [prodAdj2Id],
      );
      final result = calculate(
        const TransactionCalculationInput(
          cartItems: [kwt, prodAdj2],
          paymentSettings: null,
          paymentMethod: 'SHOPEEFOOD',
          discountInput: discount,
          promotions: [promo],
        ),
      );

      expect(result.discountAmount, closeTo(15000, 0.01));
      expect(result.promotionAmount, closeTo(128888.89, 0.01));
      expect(result.totalAmount, closeTo(45111.11, 0.01));
    });

    // Product Adj 2: effective 22000 (base 20000 + variant 2000), qty 2, one
    // free; KWT 49000 qualifies; 20% ALL.
    //   discount    = 8800 + 9800 = 18600
    //   FREE saving = 22000 − 4400 = 17600
    //   total       = 93000 − 18600 − 17600 = 56800
    test('discount_percentage_free_unit_uses_effectivePrice_when_priceAdjustment_nonzero', () {
      const productAdj2Id = 35229856970016;
      const kwtId = 34322203648028;
      const productAdj2 = CartItemData(
        productId: productAdj2Id,
        productName: 'Product adjustable 2',
        price: 22000,
        basePrice: 20000,
        quantity: 2,
        cartKey: 'adj2',
      );
      const kwt = CartItemData(
        productId: kwtId,
        productName: 'KWT SIRAM DAGING',
        price: 49000,
        quantity: 1,
        cartKey: 'kwt',
      );
      const discount = DiscountInput(
        discountId: 5,
        valueType: 'PERCENTAGE',
        value: 20,
      );
      const promo = PromotionInput(
        promotionId: 20,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'FREE',
        buyQty: 1,
        getQty: 1,
        buyScope: 'PRODUCT',
        buyProductIds: [kwtId],
        rewardScope: 'PRODUCT',
        rewardProductIds: [productAdj2Id],
      );
      final result = calculate(
        const TransactionCalculationInput(
          cartItems: [productAdj2, kwt],
          paymentSettings: null,
          paymentMethod: 'GRABFOOD',
          discountInput: discount,
          promotions: [promo],
        ),
      );

      expect(result.discountAmount, closeTo(18600, 0.01));
      expect(result.promotionAmount, closeTo(17600, 0.01));
      expect(result.totalAmount, closeTo(56800, 0.01));
    });

    test('percentage discount all with fully-free buyXGetY reward matches server payload', () {
      const categoryId = 6217366856903;
      const kwtId = 34322203648028;
      const prodAdj2Id = 35229856970016;
      const kwt = CartItemData(
        productId: kwtId,
        productName: 'KWT SIRAM DAGING',
        price: 49000,
        basePrice: 49000,
        quantity: 1,
        cartKey: 'kwt',
        categoryIds: [categoryId],
      );
      const prodAdj2 = CartItemData(
        productId: prodAdj2Id,
        productName: 'Product adjustable 2',
        price: 10000,
        basePrice: 10000,
        quantity: 1,
        cartKey: 'adj2',
        categoryIds: [categoryId],
        isPriceAdjustable: true,
        isPriceOverride: true,
      );
      const discount = DiscountInput(
        discountId: 5,
        valueType: 'PERCENTAGE',
        value: 20,
      );
      const promo = PromotionInput(
        promotionId: 20,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'FREE',
        buyQty: 1,
        getQty: 1,
        buyScope: 'CATEGORY',
        buyCategoryIds: [categoryId],
        rewardScope: 'PRODUCT',
        rewardProductIds: [prodAdj2Id],
      );

      final result = calculate(
        const TransactionCalculationInput(
          cartItems: [kwt, prodAdj2],
          paymentSettings: null,
          paymentMethod: 'SHOPEEFOOD',
          discountInput: discount,
          promotions: [promo],
        ),
      );

      expect(result.subTotal, closeTo(59000, 0.01));
      expect(result.discountAmount, closeTo(11800, 0.01));
      expect(result.promotionAmount, closeTo(8000, 0.01));
      expect(result.totalAmount, closeTo(39200, 0.01));

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'SHOPEEFOOD',
        cashTendered: '39200.00',
        discountId: 5,
        promotionIds: [20],
        discountInput: discount,
        appliedPromotions: [promo],
        cartItemsForBreakdown: [kwt, prodAdj2],
      );
      final rewardItem = lineOf(payload, prodAdj2Id);
      final qualifierItem = lineOf(payload, kwtId);

      expect(payload.discountAmount, '11800.00');
      expect(payload.promotionAmount, '8000.00');
      expect(payload.totalAmount, '39200.00');
      expect(rewardItem.discounts!.single.amt, '2000.00');
      expect(rewardItem.promotions!.single.amt, '8000.00');
      expect(qualifierItem.discounts!.single.amt, '9800.00');
      expect(qualifierItem.promotions!.single.amt, '0.00');
    });

    test('amount discount with percentage buyXGetY uses raw discount share for tax base', () {
      const categoryId = 6217366856903;
      const kwtId = 34322203648028;
      const adjustableId = 35197440779945;
      const kwt = CartItemData(
        productId: kwtId,
        productName: 'KWT SIRAM DAGING',
        price: 49000,
        basePrice: 49000,
        quantity: 1,
        cartKey: 'kwt',
        categoryIds: [categoryId],
      );
      const adjustable = CartItemData(
        productId: adjustableId,
        productName: 'Product Adjustable',
        price: 20000,
        basePrice: 20000,
        quantity: 1,
        cartKey: 'adjustable',
        categoryIds: [5763540195909],
        isTaxable: true,
        taxId: 2,
        taxPercentage: 10,
        isPriceAdjustable: true,
        isPriceOverride: true,
      );
      const discount = DiscountInput(
        discountId: 7,
        valueType: 'AMOUNT',
        value: 15000,
      );
      const promo = PromotionInput(
        promotionId: 21,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        rewardType: 'PERCENTAGE',
        rewardValue: 10,
        buyQty: 1,
        getQty: 1,
        buyScope: 'CATEGORY',
        buyCategoryIds: [categoryId],
        rewardScope: 'PRODUCT',
        rewardProductIds: [adjustableId],
      );

      final result = calculate(
        const TransactionCalculationInput(
          cartItems: [kwt, adjustable],
          paymentSettings: null,
          paymentMethod: 'GRABFOOD',
          priceIncludeTax: false,
          discountInput: discount,
          promotions: [promo],
        ),
      );

      expect(result.subTotal, closeTo(69000, 0.01));
      expect(result.discountAmount, closeTo(15000, 0.01));
      expect(result.promotionAmount, closeTo(1565, 0.01));
      expect(result.tax, closeTo(1408.72, 0.01));

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'GRABFOOD',
        cashTendered: '53844.00',
        discountId: 7,
        promotionIds: [21],
        discountInput: discount,
        appliedPromotions: [promo],
        cartItemsForBreakdown: [kwt, adjustable],
      );
      final rewardItem = lineOf(payload, adjustableId);

      expect(payload.totalTax, '1408.72');
      expect(rewardItem.taxes!.single.amt, '1408.72');
      expect(rewardItem.discounts!.single.amt, '4348.00');
      expect(rewardItem.promotions!.single.amt, '1565.00');
    });
  });
}
