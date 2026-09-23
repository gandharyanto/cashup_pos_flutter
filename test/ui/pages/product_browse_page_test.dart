import 'package:cashup_pos/src/state/cart_controller.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:cashup_pos/src/ui/pages/product_browse_page.dart';
import 'package:cashup_pos/src/ui/widgets/pos_product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_repository.dart';

void main() {
  late FakeRepository repository;

  setUp(() {
    repository = FakeRepository()
      ..products = [
        product(1, 'Kopi', categories: [10]),
        product(2, 'Teh', categories: [20]),
      ]
      ..categories = [category(10, 'Kopi'), category(20, 'Teh')];
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [posRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProductBrowsePage()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'renders the fetched catalogue and filters categories in memory',
    (tester) async {
      await pump(tester);
      expect(find.text('Kopi'), findsWidgets);
      expect(find.text('Teh'), findsWidgets);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Teh'));
      await tester.pump();

      expect(find.text('Kopi'), findsOneWidget);
      expect(repository.productListCalls, 1);
      expect(repository.categoryListCalls, 1);
    },
  );

  testWidgets('tapping a simple product adds it directly to the cart', (
    tester,
  ) async {
    repository.products = [
      const PosProduct(
        id: 1,
        name: 'Kopi',
        basePrice: 18000,
        isUnlimitedStock: true,
      ),
    ];
    final container = await pump(tester);

    await tester.tap(find.byType(PosProductTile));
    await tester.pump();

    expect(container.read(cartControllerProvider).totalQuantity, 1);
  });
}
