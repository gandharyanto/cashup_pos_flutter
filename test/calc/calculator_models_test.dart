import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/models/option_group.dart';
import 'package:flutter_test/flutter_test.dart';

CartItemData line(
  int id, {
  double price = 10000,
  int qty = 1,
  String? cartKey,
  List<int> categories = const [],
}) => CartItemData(
  productId: id,
  productName: 'P$id',
  price: price,
  quantity: qty,
  cartKey: cartKey ?? '$id',
  categoryIds: categories,
);

void main() {
  group('CartItemData', () {
    test('basePrice defaults to the effective price', () {
      final item = line(1, price: 23000);
      expect(item.basePrice, 23000);
    });

    test('keeps a distinct basePrice when variants raise the price', () {
      const item = CartItemData(
        productId: 1,
        productName: 'Kopi',
        price: 28000,
        basePrice: 18000,
        quantity: 1,
        cartKey: '1_v12',
        selectedVariants: [
          VariantOption(
            id: 12,
            variantGroupId: 1,
            name: 'Large',
            additionalPrice: 10000,
          ),
        ],
      );
      expect(item.basePrice, 18000);
      expect(item.price, 28000);
    });

    test('lineSubtotal multiplies the effective price by quantity', () {
      expect(line(1, price: 18000, qty: 3).lineSubtotal, 54000);
    });

    test('cartKey defaults to the product id', () {
      const item = CartItemData(
        productId: 7,
        productName: 'Teh',
        price: 8000,
        quantity: 1,
      );
      expect(item.cartKey, '7');
    });

    test('copyWith replaces only the quantity', () {
      final item = line(1, price: 18000, qty: 2).copyWith(quantity: 5);
      expect(item.quantity, 5);
      expect(item.price, 18000);
      expect(item.cartKey, '1');
    });

    test('equality covers every field, so it can fingerprint a cart', () {
      expect(line(1, price: 18000, qty: 2), line(1, price: 18000, qty: 2));
      expect(
        line(1, price: 18000, qty: 2),
        isNot(line(1, price: 18000, qty: 3)),
      );
      expect(
        line(1, price: 18000, qty: 2),
        isNot(line(1, price: 19000, qty: 2)),
      );
      expect(
        line(1, price: 18000, qty: 2, categories: const [3]),
        isNot(line(1, price: 18000, qty: 2)),
      );
    });

    test('equal items hash equally', () {
      expect(
        line(1, price: 18000, qty: 2).hashCode,
        line(1, price: 18000, qty: 2).hashCode,
      );
    });

    test('selected options participate in equality', () {
      const withVariant = CartItemData(
        productId: 1,
        productName: 'Kopi',
        price: 28000,
        quantity: 1,
        cartKey: '1_v12',
        selectedVariants: [
          VariantOption(id: 12, variantGroupId: 1, name: 'Large'),
        ],
      );
      const withOther = CartItemData(
        productId: 1,
        productName: 'Kopi',
        price: 28000,
        quantity: 1,
        cartKey: '1_v13',
        selectedVariants: [
          VariantOption(id: 13, variantGroupId: 1, name: 'Small'),
        ],
      );
      expect(withVariant, isNot(withOther));
    });
  });

  group('DiscountInput', () {
    test('defaults to an ALL-scope discount with no minimum', () {
      const discount = DiscountInput(valueType: 'AMOUNT', value: 5000);
      expect(discount.scope, 'ALL');
      expect(discount.minPurchase, 0);
      expect(discount.eligibleProductIds, isEmpty);
      expect(discount.isPercentage, isFalse);
    });

    test('equality covers the fields the fingerprint depends on', () {
      const a = DiscountInput(
        discountId: 4,
        valueType: 'PERCENTAGE',
        value: 10,
      );
      const b = DiscountInput(
        discountId: 4,
        valueType: 'PERCENTAGE',
        value: 10,
      );
      const c = DiscountInput(
        discountId: 4,
        valueType: 'PERCENTAGE',
        value: 15,
      );
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('PromotionInput', () {
    test('defaults match the Kotlin data class', () {
      const promo = PromotionInput(
        promotionId: 7,
        promoType: 'DISCOUNT_BY_ORDER',
        priority: 100,
        canCombine: false,
      );
      expect(promo.minPurchase, 0);
      expect(promo.isMultiplied, isFalse);
      expect(promo.buyScope, 'ALL');
      expect(promo.rewardScope, 'ALL');
      expect(promo.selectedRewardQtyMap, isEmpty);
      expect(promo.activeDays, isEmpty);
    });

    test('names the reward quantity getQty, as the calculator does', () {
      const promo = PromotionInput(
        promotionId: 7,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
        buyQty: 2,
        getQty: 1,
      );
      expect(promo.buyQty, 2);
      expect(promo.getQty, 1);
    });

    test('copyWith replaces the reward selection', () {
      const promo = PromotionInput(
        promotionId: 7,
        promoType: 'BUY_X_GET_Y',
        priority: 1,
        canCombine: true,
      );
      final selected = promo.copyWith(selectedRewardQtyMap: const {'3': 1});
      expect(selected.selectedRewardQtyMap, {'3': 1});
      expect(selected.promotionId, 7);
    });
  });

  group('TransactionCalculationResult', () {
    test('defaults every money field to zero', () {
      const result = TransactionCalculationResult(
        subTotal: 0,
        serviceCharge: 0,
        tax: 0,
        rounding: 0,
        totalAmount: 0,
        transactionItems: [],
      );
      expect(result.discountAmount, 0);
      expect(result.promotionAmount, 0);
      expect(result.appliedPromotionIds, isEmpty);
      expect(result.perPromoAmounts, isEmpty);
      expect(result.taxBreakdowns, isEmpty);
    });

    test('reports the total deduction applied to the order', () {
      const result = TransactionCalculationResult(
        subTotal: 50000,
        discountAmount: 5000,
        promotionAmount: 2000,
        serviceCharge: 0,
        tax: 0,
        rounding: 0,
        totalAmount: 43000,
        transactionItems: [],
      );
      expect(result.totalDeduction, 7000);
      expect(result.netAmount, 43000);
    });
  });

  group('PerItemSavingsResult', () {
    test('is empty by default and looks up by cart key', () {
      const empty = PerItemSavingsResult.empty();
      expect(empty.savings, isEmpty);
      expect(empty.savingFor('1'), 0);
      expect(empty.labelFor('1'), isNull);

      const result = PerItemSavingsResult(
        savings: {'1': 2500},
        labels: {'1': 'Diskon Member'},
      );
      expect(result.savingFor('1'), 2500);
      expect(result.labelFor('1'), 'Diskon Member');
      expect(result.savingFor('2'), 0);
    });
  });
}
