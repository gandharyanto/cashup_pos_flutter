import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:cashup_pos/src/ui/pages/stock_movement_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_repository.dart';

/// Wraps [FakeRepository.stockUpdate] to record the exact `updateType`
/// string the page sends. This task may only touch
/// `stock_movement_page.dart`, `manage_product_page.dart` and their test
/// files, so the shared `FakeRepository` (which does not record call
/// arguments) is subclassed here rather than modified.
class _RecordingRepository extends FakeRepository {
  String? lastUpdateType;
  int? lastQty;

  @override
  Future<void> stockUpdate({
    required int productId,
    required int qty,
    required String updateType,
  }) async {
    lastUpdateType = updateType;
    lastQty = qty;
    await super.stockUpdate(
      productId: productId,
      qty: qty,
      updateType: updateType,
    );
  }
}

void main() {
  late _RecordingRepository repository;
  late ProviderContainer container;

  const product = PosProduct(id: 1, name: 'Kopi', basePrice: 18000);

  setUp(() {
    repository = _RecordingRepository();
    container = ProviderContainer(
      overrides: [posRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StockMovementPage(product: product)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openUpdateDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Perbarui stok'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    "stock-in sends the write endpoint's ADD, never the history feed's IN",
    (tester) async {
      await pump(tester);
      await openUpdateDialog(tester);

      // "Stok masuk" (IN direction) is the default segment selection.
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(repository.stockUpdateCalls, 1);
      expect(repository.lastQty, 5);
      expect(repository.lastUpdateType, 'ADD');
      expect(repository.lastUpdateType, isNot('IN'));
    },
  );

  testWidgets(
    "stock-out sends the write endpoint's SUBSTRACT, never the history "
    "feed's OUT",
    (tester) async {
      await pump(tester);
      await openUpdateDialog(tester);

      await tester.tap(find.text('Stok keluar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(repository.stockUpdateCalls, 1);
      expect(repository.lastQty, 3);
      expect(repository.lastUpdateType, 'SUBSTRACT');
      expect(repository.lastUpdateType, isNot('OUT'));
    },
  );

  testWidgets('a zero or blank quantity does not call stockUpdate at all', (
    tester,
  ) async {
    await pump(tester);
    await openUpdateDialog(tester);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repository.stockUpdateCalls, 0);
  });
}
