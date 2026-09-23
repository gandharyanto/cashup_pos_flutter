import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:cashup_pos/src/ui/pages/manage_product_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_repository.dart';

void main() {
  test('product editor validates required name and non-negative price', () {
    expect(validateProductName('  '), 'Nama produk wajib diisi');
    expect(validateProductName('Kopi'), isNull);
    expect(validateProductPrice('abc'), 'Harga tidak valid');
    expect(validateProductPrice('-1'), 'Harga tidak valid');
    expect(validateProductPrice('0'), isNull);
    expect(validateProductPrice('15000'), isNull);
  });

  test('product editor validates required SKU and UPC', () {
    expect(validateProductSku(null), 'SKU wajib diisi');
    expect(validateProductSku('   '), 'SKU wajib diisi');
    expect(validateProductSku('SKU-1'), isNull);
    expect(validateProductUpc(null), 'UPC wajib diisi');
    expect(validateProductUpc('   '), 'UPC wajib diisi');
    expect(validateProductUpc('0123456789'), isNull);
  });

  test('product editor requires at least one selected category, matching the '
      'Kotlin category picker copy', () {
    expect(validateProductCategories(const []), 'Pilih minimal satu kategori.');
    expect(validateProductCategories(const [1]), isNull);
  });

  group('ProductEditorPage', () {
    late FakeRepository repository;
    late ProviderContainer container;
    final categories = [category(1, 'Minuman')];

    setUp(() {
      repository = FakeRepository()..categories = categories;
      container = ProviderContainer(
        overrides: [posRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ProductEditorPage(categories: categories)),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Field order for a new product (widget.product == null): Nama produk,
    // Harga, SKU, UPC, Deskripsi, Stok awal.
    Future<void> fillRequiredTextFields(WidgetTester tester) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Kopi Susu');
      await tester.enterText(fields.at(1), '18000');
      await tester.enterText(fields.at(2), 'SKU-1');
      await tester.enterText(fields.at(3), '000111');
    }

    Future<void> tapSave(WidgetTester tester) async {
      final save = find.text('Simpan');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
    }

    testWidgets(
      'blocks save and shows the Kotlin-matching message when no category '
      'is selected',
      (tester) async {
        await pump(tester);
        await fillRequiredTextFields(tester);

        await tapSave(tester);
        await tester.pumpAndSettle();

        expect(find.text('Pilih minimal satu kategori.'), findsOneWidget);
        expect(repository.productCreateCalls, 0);
      },
    );

    testWidgets(
      'blocks save when SKU and UPC are left blank even with a category '
      'selected',
      (tester) async {
        await pump(tester);
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Kopi Susu');
        await tester.enterText(fields.at(1), '18000');
        await tester.tap(find.widgetWithText(FilterChip, 'Minuman'));
        await tester.pump();

        await tapSave(tester);
        await tester.pumpAndSettle();

        expect(find.text('SKU wajib diisi'), findsOneWidget);
        expect(find.text('UPC wajib diisi'), findsOneWidget);
        expect(repository.productCreateCalls, 0);
      },
    );

    testWidgets(
      'saves once name, price, SKU, UPC and a category are all provided',
      (tester) async {
        await pump(tester);
        await fillRequiredTextFields(tester);
        await tester.tap(find.widgetWithText(FilterChip, 'Minuman'));
        await tester.pump();

        await tapSave(tester);
        await tester.pumpAndSettle();

        expect(repository.productCreateCalls, 1);
      },
    );
  });

  group('ManageProductDetailPage delete flow', () {
    late FakeRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeRepository()..products = [product(1, 'Kopi')];
      container = ProviderContainer(
        overrides: [posRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ManageProductDetailPage(productId: 1, categories: []),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'confirming the delete dialog calls PosRepository.productDelete',
      (tester) async {
        await pump(tester);

        await tester.tap(find.text('Hapus produk'));
        await tester.pumpAndSettle();
        expect(find.text('Hapus produk?'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
        await tester.pumpAndSettle();

        expect(repository.productDeleteCalls, 1);
      },
    );

    testWidgets('cancelling the confirmation dialog does not delete', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Hapus produk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(repository.productDeleteCalls, 0);
    });
  });
}
