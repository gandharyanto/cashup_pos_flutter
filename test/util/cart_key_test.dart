import 'package:cashup_pos/src/models/option_group.dart';
import 'package:cashup_pos/src/util/cart_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VariantOption variant(int id) =>
      VariantOption(id: id, variantGroupId: 1, name: 'Variant $id');

  ModifierOption modifier(int id) =>
      ModifierOption(id: id, productId: 12, name: 'Modifier $id');

  test('a plain product keys on its id alone', () {
    expect(buildCartKey(productId: 12), '12');
  });

  test('variants append in selection order, modifiers append sorted', () {
    expect(
      buildCartKey(
        productId: 12,
        variants: [variant(3), variant(1)],
        modifiers: [modifier(9), modifier(4)],
      ),
      '12_v3-1_m4-9',
    );
  });

  test('an overridden price only participates when the product is price-adjustable', () {
    expect(
      buildCartKey(
        productId: 12,
        customBasePrice: 25000,
        isPriceAdjustable: true,
      ),
      '12_p25000',
    );
    expect(buildCartKey(productId: 12, customBasePrice: 25000), '12');
  });
}
