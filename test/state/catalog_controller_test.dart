import 'package:cashup_pos/src/state/catalog_controller.dart';
import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_repository.dart';

void main() {
  late FakeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeRepository()
      ..products = [
        product(1, 'Kopi', categories: [10]),
        product(2, 'Teh', categories: [20]),
      ];
    container = ProviderContainer(
      overrides: [posRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  test('loads products and categories once', () async {
    await container.read(catalogControllerProvider.future);
    expect(repo.productListCalls, 1);
    expect(repo.categoryListCalls, 1);
  });

  test(
    'selecting a category filters in memory without another request',
    () async {
      await container.read(catalogControllerProvider.future);
      container.read(catalogControllerProvider.notifier).selectCategory(20);
      await container.pump();

      final CatalogState state = container
          .read(catalogControllerProvider)
          .requireValue;
      expect(state.visibleProducts.single.name, 'Teh');
      expect(repo.productListCalls, 1, reason: 'filtering must not refetch');
    },
  );

  test('the query filters by name and sku, case-insensitively', () async {
    await container.read(catalogControllerProvider.future);
    container.read(catalogControllerProvider.notifier).setQuery('kop');
    await container.pump();

    expect(
      container
          .read(catalogControllerProvider)
          .requireValue
          .visibleProducts
          .single
          .name,
      'Kopi',
    );
    expect(repo.productListCalls, 1);
  });
}
