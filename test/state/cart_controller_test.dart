import 'package:cashup_pos/src/models/option_group.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/state/cart_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  CartController getCart() => container.read(cartControllerProvider.notifier);

  PosProduct product(
    int id,
    String name, {
    required double price,
    int qty = 0,
    bool unlimited = false,
    bool adjustable = false,
  }) => PosProduct(
    id: id,
    name: name,
    basePrice: price,
    qty: qty,
    isUnlimitedStock: unlimited,
    isPriceAdjustable: adjustable,
  );

  VariantOption variant(int id, {double price = 0}) => VariantOption(
    id: id,
    variantGroupId: 1,
    name: 'Variant $id',
    additionalPrice: price,
  );

  test('adding the same product twice merges onto one line', () {
    final cart = getCart();
    cart.add(product(1, 'Kopi', price: 18000, unlimited: true));
    cart.add(product(1, 'Kopi', price: 18000, unlimited: true));

    final state = container.read(cartControllerProvider);
    expect(state.lines.length, 1);
    expect(state.lines.values.single.quantity, 2);
    expect(state.subTotal, 36000);
  });

  test('different variants of one product occupy separate lines', () {
    final cart = getCart();
    final p = product(1, 'Kopi', price: 18000, unlimited: true);
    cart.add(p, variants: [variant(3, price: 5000)]);
    cart.add(p, variants: [variant(4)]);

    expect(container.read(cartControllerProvider).lines.length, 2);
    expect(container.read(cartControllerProvider).subTotal, 41000);
  });

  test('the stock guard rejects going past available quantity', () {
    final cart = getCart();
    final p = product(1, 'Kopi', price: 18000, qty: 1);
    expect(cart.add(p), isNull);
    final error = cart.add(p);
    expect(error, contains('Stok'));
    expect(
      container.read(cartControllerProvider).lines.values.single.quantity,
      1,
    );
  });

  test('unlimited stock bypasses the guard', () {
    final cart = getCart();
    final p = product(1, 'Kopi', price: 18000, unlimited: true);
    expect(cart.add(p), isNull);
    expect(cart.add(p), isNull);
    expect(
      container.read(cartControllerProvider).lines.values.single.quantity,
      2,
    );
  });

  test('setting a quantity to zero removes the line', () {
    final cart = getCart();
    cart.add(product(1, 'Kopi', price: 18000, unlimited: true));
    final key = container.read(cartControllerProvider).lines.keys.single;
    cart.setQuantity(key, 0);
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });
}
