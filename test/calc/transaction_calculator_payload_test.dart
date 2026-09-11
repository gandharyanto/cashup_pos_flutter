import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/transaction_calculator.dart';
import 'package:cashup_pos/src/models/option_group.dart';
import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported from `TransactionCalculatorTest.kt` — the `buildTransactionPayload`
/// half. The `calculateTransaction` half lives in
/// `transaction_calculator_test.dart`.
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

  group('plan', () {
    test('payload money fields use US-decimal two-place strings', () {
      final result = TransactionCalculator.calculateTransaction(
        const TransactionCalculationInput(
          cartItems: [
            CartItemData(
              productId: 1,
              productName: 'Kopi',
              price: 18000,
              quantity: 2,
              cartKey: '1',
            ),
          ],
          paymentSettings: null,
          paymentMethod: 'CASH',
        ),
      );

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'CASH',
        cashTendered: '40000',
        cashChange: '4000',
      );

      final json = payload.toJson();
      expect(json['grossAmount'], '36000.00');
      expect(json['totalAmount'], '36000.00');
      // Kotlin's buildPaymentSettingRequest always emits the block, even with
      // no payment settings at all.
      expect(json['paymentSetting']['taxAppliedAfterDiscount'], isTrue);
    });

    test('service charge is emitted as a typed object only when enabled', () {
      const serviceChargeSettings = PaymentSetting(
        paymentSettingId: 1,
        isPriceIncludeTax: false,
        isRounding: false,
        roundingTarget: 0,
        roundingType: 'NONE',
        isServiceCharge: true,
        serviceChargePercentage: 5,
        serviceChargeAmount: 0,
        isTax: false,
        taxPercentage: 0,
        taxName: 'none',
      );
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'Kopi',
            price: 10000,
            quantity: 1,
            cartKey: '1',
          ),
        ],
        paymentSettings: serviceChargeSettings,
        paymentMethod: 'CARD',
      );
      final json = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'CARD',
        paymentSettings: serviceChargeSettings,
      ).toJson();

      expect(json['paymentSetting']['serviceCharge'], {
        'type': 'PERCENTAGE',
        'value': 5.0,
      });

      final disabled = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'CARD',
        paymentSettings: serviceChargeSettings.copyWith(isServiceCharge: false),
      ).toJson();
      expect(
        (disabled['paymentSetting'] as Map).containsKey('serviceCharge'),
        isFalse,
      );
    });
  });

  group('ported from TransactionCalculatorTest.kt', () {
    test(
      'buildTransactionPayload taxExclusive setsNetAmountFromTaxExclusiveBase',
      () {
        const cartItems = [
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
        ];
        final taxExclusive = settings.copyWith(
          isPriceIncludeTax: false,
          taxPercentage: 10,
        );

        final result = calculate(
          cartItems: cartItems,
          paymentSettings: taxExclusive,
          paymentMethod: 'GOFOOD',
        );

        final payload = TransactionCalculator.buildTransactionPayload(
          result: result,
          paymentMethod: 'GOFOOD',
          paymentSettings: taxExclusive,
          cartItemsForBreakdown: cartItems,
        );

        expect(payload.subTotal, '27000.00');
        expect(payload.netAmount, '27000.00');
        expect(payload.totalTax, '2700.00');
        expect(payload.totalAmount, '29700.00');
      },
    );

    test(
      'buildTransactionPayload matchesServerExpectedVariantAndPromoShape',
      () {
        const selectedVariants = [
          VariantOption(
            id: 2,
            variantGroupId: 1,
            name: 'Sedang',
            additionalPrice: 0,
            groupName: 'Level Pedas',
          ),
          VariantOption(
            id: 6,
            variantGroupId: 2,
            name: 'Paha Atas',
            additionalPrice: 2000,
            groupName: 'Potongan Ayam',
          ),
        ];
        const selectedModifiers = [
          ModifierOption(
            id: 11,
            productId: 34776030309022,
            name: 'Tempe',
            additionalPrice: 2000,
            groupId: 3,
            groupName: 'Menu Tambahan',
          ),
        ];
        const cartItems = [
          CartItemData(
            productId: 34776030309022,
            productName: 'Pecel Ayam',
            price: 29000,
            basePrice: 25000,
            quantity: 1,
            cartKey: '34776030309022',
            taxAmountPerUnit: 2900,
            isTaxable: true,
            taxId: 12,
            taxName: 'PB1',
            taxPercentage: 10,
            variantId: 6,
            selectedVariants: selectedVariants,
            selectedModifiers: selectedModifiers,
          ),
        ];
        const promo = PromotionInput(
          promotionId: 14,
          promoType: 'DISCOUNT_BY_ORDER',
          priority: 1,
          canCombine: true,
          valueType: 'AMOUNT',
          value: 2900,
        );
        final taxExclusive = settings.copyWith(
          isPriceIncludeTax: false,
          taxPercentage: 10,
        );

        final result = calculate(
          cartItems: cartItems,
          paymentSettings: taxExclusive,
          paymentMethod: 'GOFOOD',
          promotions: const [promo],
        );

        final payload = TransactionCalculator.buildTransactionPayload(
          result: result,
          paymentMethod: 'GOFOOD',
          paymentSettings: taxExclusive,
          promotionIds: const [14],
          appliedPromotions: const [promo],
          cartItemsForBreakdown: cartItems,
        );

        expect(payload.subTotal, '29000.00');
        expect(payload.netAmount, '26100.00');
        expect(payload.promotionAmount, '2900.00');
        expect(payload.promotionIds, [14]);
        // taxAppliedAfterDiscount: base = 29000 - 2900 = 26100 -> 2610
        expect(payload.totalTax, '2610.00');
        expect(payload.totalAmount, '28710.00');

        final item = payload.transactionItems.single;
        expect(item.productName, 'Pecel Ayam');
        expect(item.price, '25000.00');
        expect(item.totalPrice, '29000.00');
        expect(item.variantId, 6);
        expect(item.variantOptionIds, [2, 6]);
        expect(item.details?.length, 3);
        expect(item.details?[0].name, 'Sedang');
        expect(item.details?[1].name, 'Paha Atas');
        expect(item.details?[2].name, 'Tempe');
        expect(item.taxes?.single.amt, '2610.00');
      },
    );

    test('DISCOUNT_BY_ITEM_SUBTOTAL PERCENTAGE uses per-item integer rounding matching server', () {
      // Reproduces 400 "Total promotion mismatch: client=3733.32, server=3733.00".
      // The calculation half is asserted in transaction_calculator_test.dart;
      // this is the payload half of the same Kotlin test.
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
      const promo = PromotionInput(
        promotionId: 25,
        promoType: 'DISCOUNT_BY_ITEM_SUBTOTAL',
        priority: 1,
        canCombine: true,
        valueType: 'PERCENTAGE',
        value: 12,
      );

      final result = calculate(
        cartItems: const [brokoli, buah],
        paymentSettings: settings,
        paymentMethod: 'Credit/Debit',
        promotions: const [promo],
      );
      expect(result.promotionAmount, 3733.0);
      expect(result.tax, closeTo(977.80, 0.01));

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'Credit/Debit',
        appliedPromotions: const [promo],
        cartItemsForBreakdown: const [brokoli, buah],
      );
      final brokoliItem = payload.transactionItems.firstWhere(
        (i) => i.productId == 34419452218241,
      );
      final buahItem = payload.transactionItems.firstWhere(
        (i) => i.productId == 34516700788454,
      );

      // Per-item promotion amounts, rounded per line.
      expect(brokoliItem.promotions?.first.amt, '2400.00');
      expect(buahItem.promotions?.first.amt, '1333.00');

      // Per-item tax on the price net of the promotion.
      expect(buahItem.taxes?.first.amt, '977.80');

      // The header tax matches the per-item figure.
      expect(payload.totalTax, '977.80');
    });

    test('buildTransactionPayload keeps BUY_X_GET_Y FREE reward amount aligned with header after amount discount', () {
      const rewardItem = CartItemData(
        productId: 35197440779945,
        productName: 'Product Adjustable',
        price: 23000,
        basePrice: 14000,
        quantity: 2,
        isTaxable: true,
        taxId: 2,
        taxName: 'PB1',
        taxPercentage: 10,
        variantId: 656,
        cartKey: '35197440779945-656',
        isPriceAdjustable: true,
      );
      const qualifierItem = CartItemData(
        productId: 34322203648028,
        productName: 'KWT SIRAM DAGING',
        price: 59000,
        basePrice: 49000,
        quantity: 1,
        variantId: 621,
        cartKey: '34322203648028-621',
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
        buyQty: 1,
        getQty: 1,
        rewardType: 'FREE',
        buyScope: 'PRODUCT',
        buyProductIds: [34322203648028],
        rewardScope: 'PRODUCT',
        rewardProductIds: [35197440779945],
        selectedRewardQtyMap: {'35197440779945-656': 1},
      );
      const cartItems = [rewardItem, qualifierItem];

      final result = calculate(
        cartItems: cartItems,
        paymentSettings: settings.copyWith(isPriceIncludeTax: false),
        paymentMethod: 'CASHLEZ QRIS',
        discountInput: discount,
        promotions: const [promo],
      );
      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'CASHLEZ QRIS',
        discountId: 7,
        discountInput: discount,
        appliedPromotions: const [promo],
        cartItemsForBreakdown: cartItems,
      );
      final rewardPayloadItem = payload.transactionItems.firstWhere(
        (i) => i.productId == 35197440779945,
      );
      final rewardPromotionAmt = rewardPayloadItem.promotions
          ?.firstWhere((p) => p.meta?.role == 'REWARD')
          .amt;

      expect(result.promotionAmount, closeTo(19714.29, 0.01));
      expect(rewardPromotionAmt, payload.promotionAmount);
      expect(rewardPromotionAmt, '19714.29');
      expect(rewardPayloadItem.taxes?.first.amt, '1971.43');
    });

    test('buildTransactionPayload discount AMOUNT PRODUCT scope prorates per item', () {
      // A=50000, B=30000 eligible; AMOUNT discount 10000.
      // A takes 10000 x 50000/80000 = 6250, B takes 10000 x 30000/80000 = 3750.
      const productA = CartItemData(
        productId: 101,
        productName: 'Produk A',
        price: 50000,
        quantity: 1,
        cartKey: '101',
      );
      const productB = CartItemData(
        productId: 102,
        productName: 'Produk B',
        price: 30000,
        quantity: 1,
        cartKey: '102',
      );
      const discount = DiscountInput(
        discountId: 10,
        valueType: 'AMOUNT',
        value: 10000,
        scope: 'PRODUCT',
        eligibleProductIds: [101, 102],
      );
      const cartItems = [productA, productB];

      final result = calculate(
        cartItems: cartItems,
        paymentMethod: 'CASH',
        discountInput: discount,
      );
      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'CASH',
        discountId: 10,
        discountInput: discount,
        cartItemsForBreakdown: cartItems,
      );

      double discountOf(int productId) =>
          double.tryParse(
            payload.transactionItems
                    .firstWhere((i) => i.productId == productId)
                    .discounts
                    ?.first
                    .amt ??
                '',
          ) ??
          0;
      final discountA = discountOf(101);
      final discountB = discountOf(102);

      expect(
        discountA,
        closeTo(6250, 0.01),
        reason: 'Product A discount share',
      );
      expect(
        discountB,
        closeTo(3750, 0.01),
        reason: 'Product B discount share',
      );
      expect(
        discountA + discountB,
        closeTo(10000, 0.01),
        reason: 'total per-item discount sums to 10000',
      );
    });
  });

  group('payload header', () {
    const taxedLine = CartItemData(
      productId: 1,
      productName: 'Item',
      price: 18055,
      quantity: 1,
      cartKey: '1',
      isTaxable: true,
      taxId: 1,
      taxPercentage: 10,
    );

    test('non-cash totalAmount is rebuilt from whole-rupiah components', () {
      // tax = 1805.5, so the unrounded total is 19860.5. The payload sends
      // round(18055) - 0 + round(0) + round(0) + round(1805.5) = 19861,
      // while totalTax stays the aggregate 1805.50.
      final result = calculate(cartItems: const [taxedLine]);
      expect(result.totalAmount, 19860.5);

      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        cartItemsForBreakdown: const [taxedLine],
      );

      expect(payload.totalAmount, '19861.00');
      expect(payload.totalTax, '1805.50');
    });

    test('cash totalAmount is the already-rounded result total', () {
      final result = calculate(
        cartItems: const [taxedLine],
        paymentMethod: 'CASH',
      );
      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'cash',
        cartItemsForBreakdown: const [taxedLine],
      );

      // Cash settles to whole rupiah inside calculateTransaction: 19860.5 ->
      // 19861, and the rounding line records the 0.50 it added.
      expect(payload.totalAmount, '19861.00');
      expect(payload.totalTax, '1806.00');
      expect(payload.totalRounding, '0.50');
    });

    test('priceIncludeTax totalAmount does not add tax again', () {
      const inclusiveLine = CartItemData(
        productId: 1,
        productName: 'Item B',
        price: 10000,
        quantity: 1,
        cartKey: '1',
        isTaxable: true,
        taxId: 1,
        taxPercentage: 10,
      );
      final result = calculate(
        cartItems: const [inclusiveLine],
        priceIncludeTax: true,
      );
      final json = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        priceIncludeTax: true,
        cartItemsForBreakdown: const [inclusiveLine],
      ).toJson();

      expect(json['totalAmount'], '10000.00');
      expect(json['totalTax'], '909.09');
      expect(json['paymentSetting']['priceIncludeTax'], isTrue);
    });

    test(
      'paymentSetting.priceIncludeTax comes from the settings when present',
      () {
        final result = calculate(cartItems: const [taxedLine]);
        final json = TransactionCalculator.buildTransactionPayload(
          result: result,
          paymentMethod: 'QRIS',
          paymentSettings: settings,
        ).toJson();

        expect(json['paymentSetting'], {
          'priceIncludeTax': true,
          'taxAppliedAfterDiscount': true,
        });
      },
    );

    test('a flat service charge is emitted as AMOUNT', () {
      final flat = settings.copyWith(
        isServiceCharge: true,
        serviceChargePercentage: 0,
        serviceChargeAmount: 1500,
      );
      final result = calculate(cartItems: const [taxedLine]);
      final json = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        paymentSettings: flat,
      ).toJson();

      expect(json['paymentSetting']['serviceCharge'], {
        'type': 'AMOUNT',
        'value': 1500.0,
      });
    });

    test('zero discount and promotion are omitted, not sent as 0.00', () {
      final result = calculate(cartItems: const [taxedLine]);
      final json = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
      ).toJson();

      expect(json.containsKey('totalDiscount'), isFalse);
      expect(json.containsKey('totalPromotionAmount'), isFalse);
      expect(json.containsKey('appliedPromotionIds'), isFalse);
      expect(json['netAmount'], '18055.00');
    });

    test('promotion ids fall back to the applied ids when none are given', () {
      const promo = PromotionInput(
        promotionId: 11,
        promoType: 'DISCOUNT_BY_ORDER',
        priority: 1,
        canCombine: true,
        valueType: 'AMOUNT',
        value: 5000,
      );
      final result = calculate(
        cartItems: const [taxedLine],
        promotions: const [promo],
      );

      final fallback = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        promotionIds: const [],
      ).toJson();
      expect(fallback['appliedPromotionIds'], [11]);
      expect(fallback['totalPromotionAmount'], '5000.00');

      final explicit = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        promotionIds: const [99],
      ).toJson();
      expect(explicit['appliedPromotionIds'], [99]);
    });

    test('blank notes are dropped; cash strings and queue pass through', () {
      final result = calculate(cartItems: const [taxedLine]);

      final blank = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        notes: '   ',
      ).toJson();
      expect(blank.containsKey('notes'), isFalse);
      expect(blank['cashTendered'], '0');
      expect(blank['cashChange'], '0');

      final withNotes = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        notes: 'tanpa gula',
        queueNumber: 7,
        discountId: 3,
      ).toJson();
      expect(withNotes['notes'], 'tanpa gula');
      expect(withNotes['queueNumber'], 7);
      expect(withNotes['discountId'], 3);
    });
  });

  group('payload items', () {
    test('without a breakdown cart, the result lines are sent as they are', () {
      final result = calculate(
        cartItems: const [
          CartItemData(
            productId: 1,
            productName: 'Pecel Ayam',
            price: 27000,
            quantity: 1,
            cartKey: '1',
            isTaxable: true,
            taxId: 12,
            taxPercentage: 10,
          ),
        ],
      );
      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
      );

      final item = payload.transactionItems.single;
      expect(item.price, '27000');
      expect(item.taxAmount, '2700');
      expect(item.taxes, isNull);
    });

    test('items are sorted by their first discount amount, ascending and stably', () {
      // Tax-free lines so the breakdown carries discounts only.
      // PERCENTAGE 10%: A -> 5000, B -> 1000, C -> 0 (not eligible), D -> 1000.
      const a = CartItemData(
        productId: 1,
        productName: 'A',
        price: 50000,
        quantity: 1,
        cartKey: 'a',
      );
      const b = CartItemData(
        productId: 2,
        productName: 'B',
        price: 10000,
        quantity: 1,
        cartKey: 'b',
      );
      const c = CartItemData(
        productId: 3,
        productName: 'C',
        price: 70000,
        quantity: 1,
        cartKey: 'c',
      );
      const d = CartItemData(
        productId: 4,
        productName: 'D',
        price: 10000,
        quantity: 1,
        cartKey: 'd',
      );
      const discount = DiscountInput(
        discountId: 5,
        valueType: 'PERCENTAGE',
        value: 10,
        scope: 'PRODUCT',
        eligibleProductIds: [1, 2, 4],
      );
      const cartItems = [a, b, c, d];

      final result = calculate(cartItems: cartItems, discountInput: discount);
      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        discountId: 5,
        discountInput: discount,
        cartItemsForBreakdown: cartItems,
      );

      expect(payload.transactionItems.map((i) => i.productName), [
        'C',
        'B',
        'D',
        'A',
      ]);
      final first = payload.transactionItems[1].discounts!.single;
      expect(first.id, 5);
      expect(first.type, 'PERCENTAGE');
      expect(first.value, 10.0);
      expect(first.amt, '1000.00');
      expect(payload.transactionItems.first.discounts, isNull);
    });

    test('breakdown lines carry base price, flags only when true, and no legacy tax fields', () {
      const adjustable = CartItemData(
        productId: 1,
        productName: 'Adjustable',
        price: 12000,
        basePrice: 10000,
        quantity: 2,
        cartKey: '1',
        isTaxable: true,
        taxId: 4,
        taxPercentage: 11,
        isPriceAdjustable: true,
        isPriceOverride: true,
      );
      const plainLine = CartItemData(
        productId: 2,
        productName: 'Plain',
        price: 5000,
        quantity: 1,
        cartKey: '2',
      );
      const cartItems = [adjustable, plainLine];

      final result = calculate(cartItems: cartItems);
      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        cartItemsForBreakdown: cartItems,
      );

      final adjustableJson = payload.transactionItems
          .firstWhere((i) => i.productId == 1)
          .toJson();
      expect(adjustableJson['price'], '10000.00');
      expect(adjustableJson['totalPrice'], '24000.00');
      expect(adjustableJson['isPriceAdjustable'], isTrue);
      expect(adjustableJson['isPriceOverride'], isTrue);
      expect(adjustableJson.containsKey('taxId'), isFalse);
      expect(adjustableJson.containsKey('taxAmount'), isFalse);
      expect(adjustableJson['taxes'], [
        {'id': 4, 'type': 'PERCENTAGE', 'value': 11.0, 'amt': '2640.00'},
      ]);

      final plainJson = payload.transactionItems
          .firstWhere((i) => i.productId == 2)
          .toJson();
      expect(plainJson.containsKey('isPriceAdjustable'), isFalse);
      expect(plainJson.containsKey('isPriceOverride'), isFalse);
      expect(plainJson.containsKey('taxes'), isFalse);
    });

    test('a fully free BUY_X_GET_Y reward line carries no tax row', () {
      const gula = CartItemData(
        productId: 1,
        productName: 'Gula',
        price: 10000,
        quantity: 1,
        cartKey: '1',
      );
      const prima = CartItemData(
        productId: 2,
        productName: 'Prima',
        price: 8000,
        quantity: 1,
        cartKey: '2',
        isTaxable: true,
        taxId: 1,
        taxPercentage: 10,
      );
      const promo = PromotionInput(
        promotionId: 1,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        buyQty: 1,
        getQty: 1,
        rewardType: 'FREE',
        buyScope: 'PRODUCT',
        buyProductIds: [1],
        rewardScope: 'PRODUCT',
        rewardProductIds: [2],
      );

      final result = calculate(
        cartItems: const [gula, prima],
        promotions: const [promo],
      );
      final payload = TransactionCalculator.buildTransactionPayload(
        result: result,
        paymentMethod: 'QRIS',
        appliedPromotions: const [promo],
        cartItemsForBreakdown: const [gula, prima],
      );

      final primaItem = payload.transactionItems.firstWhere(
        (i) => i.productId == 2,
      );
      expect(primaItem.taxes, isNull);
      final reward = primaItem.promotions!.single;
      expect(reward.id, 1);
      expect(reward.type, 'BUY_X_GET_Y');
      expect(reward.meta?.role, 'REWARD');
      expect(reward.amt, '8000.00');
      expect(payload.totalTax, '0.00');
    });
  });

  group('buildTransactionDetails', () {
    final dateShape = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$');

    const settingsWithRounding = PaymentSetting(
      paymentSettingId: 1,
      isPriceIncludeTax: false,
      isRounding: true,
      roundingTarget: 100,
      roundingType: 'CEILING',
      isServiceCharge: true,
      serviceChargePercentage: 5,
      serviceChargeAmount: 0,
      isTax: false,
      taxPercentage: 0,
      taxName: 'none',
    );

    const line = CartItemData(
      productId: 7,
      productName: 'Kopi Susu',
      price: 18000,
      quantity: 2,
      cartKey: '7',
      selectedModifiers: [
        ModifierOption(
          id: 3,
          productId: 7,
          name: 'Boba',
          additionalPrice: 3000,
          groupId: 9,
          groupName: 'Topping',
        ),
      ],
    );

    test('mirrors the calculation result into the receipt pricing', () {
      final result = calculate(
        cartItems: const [line],
        paymentSettings: settingsWithRounding,
        paymentMethod: 'CASH',
        discountInput: const DiscountInput(valueType: 'AMOUNT', value: 1000),
      );

      final details = TransactionCalculator.buildTransactionDetails(
        result: result,
        transactionId: 42,
        transactionCode: 'TRX-42',
        paymentMethod: 'CASH',
        cashTendered: 50000,
        cashChange: 12200,
        paymentSettings: settingsWithRounding,
        notes: 'meja 3',
      );

      expect(details.transactionId, 42);
      expect(details.code, 'TRX-42');
      expect(details.status, 'COMPLETED');
      expect(details.paymentMethod, 'CASH');
      expect(details.notes, 'meja 3');
      expect(details.cashTendered, 50000.0);
      expect(details.cashChange, 12200.0);
      expect(details.transactionDate, matches(dateShape));
      expect(details.payments, isEmpty);

      final pricing = details.pricing!;
      expect(pricing.baseAmount, result.subTotal);
      expect(pricing.grossAmount, result.subTotal);
      expect(pricing.discountTotal, result.discountAmount);
      expect(pricing.promotionTotal, result.promotionAmount);
      expect(
        pricing.netAmount,
        result.subTotal - result.discountAmount - result.promotionAmount,
      );
      expect(pricing.serviceChargePercentage, 5.0);
      expect(pricing.serviceChargeTotal, result.serviceCharge);
      expect(pricing.taxTotal, result.tax);
      expect(pricing.roundingType, 'CEILING');
      expect(pricing.roundingTarget, '100');
      expect(pricing.roundingTotal, result.rounding);
      expect(pricing.totalAmount, result.totalAmount);

      final receiptLine = details.transactionItems.single;
      expect(receiptLine.productId, 7);
      expect(receiptLine.productName, 'Kopi Susu');
      expect(receiptLine.price, 18000.0);
      expect(receiptLine.qty, 2);
      expect(receiptLine.grossLineTotal, 36000.0);
      expect(receiptLine.totalPrice, 36000.0);
      expect(receiptLine.details.single.name, 'Boba');
      expect(receiptLine.details.single.detailType, 'MODIFIER');
      expect(receiptLine.details.single.groupReferenceId, 9);
    });

    test('defaults the pricing settings when there are none', () {
      final result = calculate(cartItems: const [line]);
      final details = TransactionCalculator.buildTransactionDetails(
        result: result,
        transactionId: 1,
        transactionCode: 'TRX-1',
        paymentMethod: 'QRIS',
      );

      expect(details.pricing!.serviceChargePercentage, 0.0);
      expect(details.pricing!.roundingType, 'NONE');
      expect(details.pricing!.roundingTarget, '0');
      expect(details.cashTendered, 0.0);
      expect(details.payments, isEmpty, reason: 'no invoice, no payment row');
    });

    test('records a paid QRIS or CDCP payment when an invoice is given', () {
      final result = calculate(cartItems: const [line]);

      for (final method in ['QRIS', 'CDCP']) {
        final details = TransactionCalculator.buildTransactionDetails(
          result: result,
          transactionId: 9,
          transactionCode: 'TRX-9',
          paymentMethod: method,
          qrisInvoice: 'INV-001',
        );
        final payment = details.payments.single;
        expect(payment.transactionId, 9);
        expect(payment.amountPaid, result.totalAmount);
        expect(payment.paymentMethod, method);
        expect(payment.paymentReference, 'INV-001');
        expect(payment.status, 'PAID');
        expect(payment.paymentDate, matches(dateShape));
      }

      final card = TransactionCalculator.buildTransactionDetails(
        result: result,
        transactionId: 9,
        transactionCode: 'TRX-9',
        paymentMethod: 'CARD',
        qrisInvoice: 'INV-001',
      );
      expect(card.payments, isEmpty);
    });
  });
}
