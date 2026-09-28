import 'package:cashup_pos/src/data/pos_exception.dart';
import 'package:cashup_pos/src/models/paged_result.dart';
import 'package:cashup_pos/src/models/pos_category.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
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

  test('when both requests fail offline, no error escapes unhandled', () async {
    final offline = ProviderContainer(
      overrides: [
        posRepositoryProvider.overrideWithValue(_OfflineRepository()),
      ],
    );
    addTearDown(offline.dispose);

    await expectLater(
      offline.read(catalogControllerProvider.future),
      throwsA(
        isA<PosException>().having((e) => e.kind, 'kind', PosErrorKind.network),
      ),
    );
    // Let the second (category) failure settle; an unobserved rejection
    // would be reported to this test's zone and fail it.
    await Future<void>.delayed(Duration.zero);
  });
}

/// Both catalogue calls fail, as they do when the device has no connection.
class _OfflineRepository extends FakeRepository {
  static const _offline = PosException(
    kind: PosErrorKind.network,
    message: 'offline',
  );

  @override
  Future<PagedResult<PosProduct>> productList({
    int size = 100,
    int? categoryId,
    String? keyword,
    String? upc,
    String? sku,
    String? sortBy,
    String? sortDir,
  }) async => throw _offline;

  @override
  Future<PagedResult<PosCategory>> categoryList({int size = 100}) async =>
      throw _offline;
}
