import 'package:cashup_pos/src/models/option_group.dart';
import 'package:cashup_pos/src/models/paged_result.dart';
import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:cashup_pos/src/models/pos_category.dart';
import 'package:cashup_pos/src/models/pos_payment_method.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PosProduct', () {
    test('tolerates the loose typing the backend sends', () {
      final product = PosProduct.fromJson(const {
        'id': 12,
        'name': 'Kopi Susu',
        'basePrice': '18000.00', // string, not number
        'isTaxable': 'true', // string, not bool
        'qty': 5,
        'productType': 'SIMPLE',
        'categories': [
          {'id': 3, 'name': 'Minuman'},
        ],
        'tax': {'taxId': 1, 'taxName': 'PPN', 'taxPercentage': 11},
      });

      expect(product.id, 12);
      expect(product.basePrice, 18000.0);
      expect(product.isTaxable, isTrue);
      expect(product.categoryIds, [3]);
      expect(product.tax!.taxPercentage, 11.0);
      expect(product.isSimple, isTrue);
    });

    test('falls back to productImages when imageUrl is absent', () {
      final product = PosProduct.fromJson(const {
        'id': 1,
        'name': 'Teh',
        'productImages': [
          {
            'id': 9,
            'fullImage': '/img/full.png',
            'thumbImage': '/img/thumb.png',
          },
        ],
      });
      expect(product.effectiveImageUrl, '/img/full.png');
      expect(product.effectiveThumbUrl, '/img/thumb.png');
    });

    test('prefers the flat image field over productImages', () {
      final product = PosProduct.fromJson(const {
        'id': 1,
        'name': 'Teh',
        'imageUrl': '/img/flat.png',
        'productImages': [
          {'id': 9, 'fullImage': '/img/full.png'},
        ],
      });
      expect(product.effectiveImageUrl, '/img/flat.png');
    });

    test('treats an empty image string as absent', () {
      final product = PosProduct.fromJson(const {
        'id': 1,
        'name': 'Teh',
        'imageUrl': '',
        'productImages': [
          {'id': 9, 'fullImage': '/img/full.png'},
        ],
      });
      expect(product.effectiveImageUrl, '/img/full.png');
    });

    test('defaults a missing productType to SIMPLE', () {
      final product = PosProduct.fromJson(const {'id': 1, 'name': 'Teh'});
      expect(product.isSimple, isTrue);
      expect(product.isVariant, isFalse);
      expect(product.productType, PosProduct.typeSimple);
    });

    test('reports a variant product', () {
      final product = PosProduct.fromJson(const {
        'id': 1,
        'name': 'Kopi',
        'productType': 'VARIANT',
      });
      expect(product.isVariant, isTrue);
      expect(product.isSimple, isFalse);
    });

    test('falls back to basePrice when finalPrice is absent', () {
      final product = PosProduct.fromJson(const {
        'id': 1,
        'name': 'Kopi',
        'basePrice': 18000,
      });
      expect(product.finalPrice, 18000.0);
    });

    test('round-trips through json', () {
      final original = PosProduct.fromJson(const {
        'id': 12,
        'name': 'Kopi Susu',
        'sku': 'KS-1',
        'basePrice': 18000,
        'isTaxable': true,
        'isUnlimitedStock': true,
        'qty': 5,
        'categories': [
          {'id': 3, 'name': 'Minuman'},
        ],
      });
      final restored = PosProduct.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.sku, original.sku);
      expect(restored.basePrice, original.basePrice);
      expect(restored.isUnlimitedStock, isTrue);
      expect(restored.categoryIds, original.categoryIds);
    });
  });

  group('PosCategory', () {
    test('parses the list payload shape', () {
      final category = PosCategory.fromJson(const {
        'id': 3,
        'name': 'Minuman',
        'imageUrl': '/img/c.png',
        'description': 'Semua minuman',
      });
      expect(category.id, 3);
      expect(category.name, 'Minuman');
      expect(category.imageUrl, '/img/c.png');
    });
  });

  group('PagedResult', () {
    test('reads the envelope, the meta base url and the paging fields', () {
      final page = PagedResult.fromJson(const {
        'status': '200',
        'meta': {'baseUrl': 'https://cdn.test/'},
        'data': [
          {'id': 3, 'name': 'Minuman'},
        ],
        'page': 0,
        'size': 20,
        'totalElements': 1,
        'totalPages': 1,
      }, PosCategory.fromJson);

      expect(page.items.single.name, 'Minuman');
      expect(page.baseUrl, 'https://cdn.test/');
      expect(page.totalElements, 1);
      expect(page.hasMore, isFalse);
    });

    test('reports more pages when the current one is not the last', () {
      final page = PagedResult.fromJson(const {
        'data': [],
        'page': 0,
        'size': 20,
        'totalPages': 3,
      }, PosCategory.fromJson);
      expect(page.hasMore, isTrue);
    });

    test('survives a null data array', () {
      final page = PagedResult.fromJson(const {
        'status': '200',
      }, PosCategory.fromJson);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  group('option groups', () {
    const groupsJson = {
      'productId': 12,
      'productType': 'VARIANT',
      'isPriceAdjustable': true,
      'variantGroups': [
        {
          'groupId': 1,
          'name': 'Ukuran',
          'groupType': 'VARIANT',
          'selectionType': 'SINGLE',
          'isRequired': true,
          'minSelection': 1,
          'maxSelection': 1,
          'options': [
            {'optionId': 11, 'name': 'Small', 'priceAdjustment': 0},
            {'optionId': 12, 'name': 'Large', 'priceAdjustment': 10000},
          ],
        },
      ],
      'modifierGroups': [
        {
          'groupId': 5,
          'name': 'Topping',
          'groupType': 'MODIFIER',
          'selectionType': 'MULTIPLE',
          'isRequired': false,
          'minSelection': 0,
          'maxSelection': 2,
          'options': [
            {'optionId': 51, 'name': 'Boba', 'priceAdjustment': 3000},
          ],
        },
      ],
    };

    test('parses variant and modifier groups', () {
      final groups = ProductOptionGroups.fromJson(groupsJson);

      expect(groups.productId, 12);
      expect(groups.isPriceAdjustable, isTrue);
      expect(groups.variantGroups.single.name, 'Ukuran');
      expect(groups.variantGroups.single.isSingleSelection, isTrue);
      expect(groups.modifierGroups.single.maxSelection, 2);
      expect(groups.modifierGroups.single.isSingleSelection, isFalse);
      expect(groups.hasAnyOption, isTrue);
    });

    test('reports no options when both group lists are empty', () {
      final groups = ProductOptionGroups.fromJson(const {
        'productId': 1,
        'productType': 'SIMPLE',
      });
      expect(groups.hasAnyOption, isFalse);
    });

    test('maps a chosen option into the VariantOption the cart layer uses', () {
      final groups = ProductOptionGroups.fromJson(groupsJson);
      final group = groups.variantGroups.single;
      final variant = VariantOption.fromOption(group.options.last, group);

      expect(variant.id, 12);
      expect(variant.variantGroupId, 1);
      expect(variant.name, 'Large');
      expect(variant.additionalPrice, 10000);
      expect(variant.groupName, 'Ukuran');
    });

    test(
      'maps a chosen option into the ModifierOption the cart layer uses',
      () {
        final groups = ProductOptionGroups.fromJson(groupsJson);
        final group = groups.modifierGroups.single;
        final modifier = ModifierOption.fromOption(
          group.options.single,
          group,
          productId: 12,
        );

        expect(modifier.id, 51);
        expect(modifier.productId, 12);
        expect(modifier.groupId, 5);
        expect(modifier.groupName, 'Topping');
        expect(modifier.additionalPrice, 3000);
      },
    );

    test('a required modifier group needs at least one selection', () {
      final group = OptionGroup.fromJson(const {
        'groupId': 5,
        'name': 'Topping',
        'groupType': 'MODIFIER',
        'isRequired': true,
        'minSelection': 0,
        'options': [],
      });
      // Kotlin coerces minSelection to at least 1 for required groups.
      expect(group.effectiveMinSelection, 1);
    });

    test('an optional group keeps its declared minimum', () {
      final group = OptionGroup.fromJson(const {
        'groupId': 5,
        'name': 'Topping',
        'groupType': 'MODIFIER',
        'isRequired': false,
        'minSelection': 0,
        'options': [],
      });
      expect(group.effectiveMinSelection, 0);
    });
  });

  group('PaymentSetting', () {
    const json = {
      'paymentSettingId': 4,
      'isPriceIncludeTax': false,
      'isRounding': true,
      'roundingTarget': 100,
      'roundingType': 'CEILING',
      'isServiceCharge': true,
      'serviceChargePercentage': 5.0,
      'serviceChargeAmount': 0.0,
      'isTax': true,
      'taxPercentage': 11.0,
      'taxName': 'PPN',
    };

    test('round-trips through json', () {
      final setting = PaymentSetting.fromJson(json);
      expect(setting.roundingType, 'CEILING');
      expect(PaymentSetting.fromJson(setting.toJson()).roundingTarget, 100);
    });

    test('exposes a default suitable for a merchant with no settings yet', () {
      const setting = PaymentSetting.defaults();
      expect(setting.isRounding, isFalse);
      expect(setting.isServiceCharge, isFalse);
      expect(setting.isTax, isFalse);
      expect(setting.roundingType, 'NONE');
    });

    test('copyWith replaces only the named fields', () {
      final setting = PaymentSetting.fromJson(json).copyWith(isRounding: false);
      expect(setting.isRounding, isFalse);
      expect(setting.roundingTarget, 100);
      expect(setting.taxName, 'PPN');
    });
  });

  group('PosPaymentMethod', () {
    test('splits the internal and external lists', () {
      final methods = PosPaymentMethod.listFromJson(const {
        'internalPayments': [
          {'code': 'CASH', 'name': 'Tunai', 'displayOrder': 1},
        ],
        'externalPayments': [
          {'code': 'QRIS', 'name': 'QRIS', 'displayOrder': 2},
        ],
      });

      expect(methods.internal.single.code, 'CASH');
      expect(methods.external.single.code, 'QRIS');
      expect(methods.all.length, 2);
    });

    test('orders each list by displayOrder', () {
      final methods = PosPaymentMethod.listFromJson(const {
        'internalPayments': [
          {'code': 'CARD', 'name': 'Kartu', 'displayOrder': 2},
          {'code': 'CASH', 'name': 'Tunai', 'displayOrder': 1},
        ],
      });
      expect(methods.internal.map((m) => m.code), ['CASH', 'CARD']);
    });

    test('skips entries without a code', () {
      final methods = PosPaymentMethod.listFromJson(const {
        'internalPayments': [
          {'name': 'Tanpa kode'},
          {'code': 'CASH', 'name': 'Tunai'},
        ],
      });
      expect(methods.internal.single.code, 'CASH');
    });
  });
}
