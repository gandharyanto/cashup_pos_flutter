import 'package:cashup_pos/src/models/discount_item.dart';
import 'package:cashup_pos/src/models/option_group.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/models/promotion_item.dart';
import 'package:cashup_pos/src/state/cart_controller.dart';
import 'package:cashup_pos/src/util/calc_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every discount field used by the calculator', () {
    const item = DiscountItem(
      id: 7,
      name: 'Member',
      valueType: 'PERCENTAGE',
      value: 10,
      scope: 'PRODUCT',
      maxDiscountAmount: 5000,
      minPurchase: 20000,
      targetProductIds: [1, 2],
      categoryIds: [3],
    );

    final mapped = toDiscountInput(item);
    expect(mapped.discountId, 7);
    expect(mapped.name, 'Member');
    expect(mapped.valueType, 'PERCENTAGE');
    expect(mapped.value, 10);
    expect(mapped.scope, 'PRODUCT');
    expect(mapped.eligibleProductIds, [1, 2]);
    expect(mapped.eligibleCategoryIds, [3]);
  });

  test(
    'maps order promotion fallback values, scopes, schedule and rewards',
    () {
      const item = PromotionItem(
        id: 9,
        name: 'Promo',
        promoType: PromotionItem.typeDiscountByOrder,
        rewardValueType: 'PERCENTAGE',
        rewardDiscountValue: 15,
        buyCategoryIds: [4],
        rewardProductIds: [8],
        schedule: PromotionSchedule(
          activeDays: ['MON'],
          startTime: '08:00',
          endTime: '17:00',
        ),
      );

      final mapped = toPromotionInputs(
        const [item],
        selectedRewards: {
          9: {'line-8': 2},
        },
      ).single;
      expect(mapped.valueType, 'PERCENTAGE');
      expect(mapped.value, 15);
      expect(mapped.buyScope, 'CATEGORY');
      expect(mapped.rewardScope, 'PRODUCT');
      expect(mapped.activeDays, ['MON']);
      expect(mapped.selectedRewardQtyMap, {'line-8': 2});
    },
  );

  test('maps a cart line without losing tax, category or override data', () {
    const product = PosProduct(
      id: 1,
      name: 'Kopi',
      basePrice: 18000,
      isTaxable: true,
      isPriceAdjustable: true,
      tax: PosTax(taxId: 2, taxName: 'PB1', taxPercentage: 10, taxAmount: 1800),
    );
    const line = PosCartLine(
      product: product,
      quantity: 2,
      customBasePrice: 20000,
      cartKey: '1_p20000',
    );

    final mapped = toCartItemData(line);
    expect(mapped.price, 20000);
    expect(mapped.basePrice, 20000);
    expect(mapped.taxId, 2);
    expect(mapped.taxAmountPerUnit, 1800);
    expect(mapped.cartKey, '1_p20000');
    expect(mapped.isPriceOverride, isTrue);
  });

  test('maps variantId from the last selected variant, matching Kotlin', () {
    const product = PosProduct(
      id: 1,
      name: 'Kopi',
      basePrice: 18000,
      isTaxable: false,
      isPriceAdjustable: false,
    );
    const line = PosCartLine(
      product: product,
      quantity: 1,
      cartKey: '1_v1_v2',
      selectedVariants: [
        VariantOption(id: 101, variantGroupId: 1, name: 'Size: Large'),
        VariantOption(id: 202, variantGroupId: 2, name: 'Sugar: Less'),
      ],
    );

    final mapped = toCartItemData(line);

    expect(mapped.variantId, 202);
    expect(mapped.variantId, isNot(101));
  });
}
