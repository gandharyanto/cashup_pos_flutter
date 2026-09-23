import 'package:cashup_pos/src/calc/transaction_calculator.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/state/cart_controller.dart';
import 'package:cashup_pos/src/state/checkout_controller.dart';
import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    TransactionCalculator.debugCalculationCount = 0;
    container = ProviderContainer(
      overrides: [
        paymentSettingProvider.overrideWith((ref) async => null),
        activePromotionsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
  });

  PosProduct product(
    int id,
    String name, {
    required double price,
    bool unlimited = false,
  }) => PosProduct(
    id: id,
    name: name,
    basePrice: price,
    isUnlimitedStock: unlimited,
  );

  test('totals reflect the cart', () async {
    container
        .read(cartControllerProvider.notifier)
        .add(product(1, 'Kopi', price: 18000, unlimited: true));
    await container.pump();

    expect(container.read(checkoutTotalsProvider).subTotal, 18000);
  });

  test('reading the totals repeatedly does not recompute', () async {
    container
        .read(cartControllerProvider.notifier)
        .add(product(1, 'Kopi', price: 18000, unlimited: true));
    await container.pump();

    container.read(checkoutTotalsProvider);
    final countAfterFirst = TransactionCalculator.debugCalculationCount;
    container.read(checkoutTotalsProvider);
    container.read(checkoutTotalsProvider);
    container.read(checkoutTotalsProvider);

    expect(
      TransactionCalculator.debugCalculationCount,
      countAfterFirst,
      reason:
          'the fingerprint is unchanged, so the cached result must be reused',
    );
  });

  test('changing a quantity recomputes exactly once', () async {
    container
        .read(cartControllerProvider.notifier)
        .add(product(1, 'Kopi', price: 18000, unlimited: true));
    await container.pump();
    container.read(checkoutTotalsProvider);
    final before = TransactionCalculator.debugCalculationCount;

    final key = container.read(cartControllerProvider).lines.keys.single;
    container.read(cartControllerProvider.notifier).setQuantity(key, 3);
    await container.pump();

    expect(TransactionCalculator.debugCalculationCount, before + 1);
    expect(container.read(checkoutTotalsProvider).subTotal, 54000);
  });
}
