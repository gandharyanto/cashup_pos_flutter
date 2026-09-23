import 'package:cashup_pos/src/models/discount_item.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/state/cart_controller.dart';
import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:cashup_pos/src/ui/pages/cart_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_repository.dart';

void main() {
  late FakeRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeRepository();
    container = ProviderContainer(
      overrides: [posRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cart pane shows lines and calculation totals', (tester) async {
    container
        .read(cartControllerProvider.notifier)
        .add(
          const PosProduct(
            id: 1,
            name: 'Kopi',
            basePrice: 18000,
            isUnlimitedStock: true,
          ),
        );
    await pump(tester, const CartPane());

    expect(find.text('Kopi'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Rp 18.000'), findsWidgets);
  });

  testWidgets('ineligible discounts are disabled', (tester) async {
    repository.discountListResult = const [
      DiscountItem(
        id: 1,
        name: 'Minimum 100 ribu',
        valueType: 'AMOUNT',
        value: 10000,
        scope: 'ALL',
        minPurchase: 100000,
      ),
    ];
    container
        .read(cartControllerProvider.notifier)
        .add(
          const PosProduct(
            id: 1,
            name: 'Kopi',
            basePrice: 18000,
            isUnlimitedStock: true,
          ),
        );
    await pump(tester, const DiscountPickerSheet());

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Minimum 100 ribu'),
    );
    expect(tile.enabled, isFalse);
    expect(tile.onTap, isNull);
  });
}
