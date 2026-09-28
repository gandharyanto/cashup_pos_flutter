import 'package:cashup_pos/src/data/pos_repository_impl.dart';
import 'package:cashup_pos/src/models/pos_area.dart';
import 'package:cashup_pos/src/models/pos_merchant_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api_client.dart'; // records paths, returns canned bodies

void main() {
  test('areaList sends the documented query parameters', () async {
    final api = FakeApiClient({
      'pos/area/list': {'status': '200', 'data': []},
    });
    final repo = PosRepositoryImpl(api);

    await repo.areaList(size: 50, keyword: 'jak');

    expect(api.lastPath, 'pos/area/list');
    expect(api.lastQuery, containsPair('size', 50));
    expect(api.lastQuery, containsPair('keyword', 'jak'));
  });

  test('areaList omits keyword from the query when not given', () async {
    final api = FakeApiClient({
      'pos/area/list': {'status': '200', 'data': []},
    });

    await PosRepositoryImpl(api).areaList();

    expect(api.lastQuery, containsPair('size', 100));
    expect(api.lastQuery, isNot(contains('keyword')));
  });

  test(
    'areaList maps the envelope into a PagedResult with the meta base url',
    () async {
      final api = FakeApiClient({
        'pos/area/list': {
          'status': '200',
          'meta': {'baseUrl': 'https://cdn.test/'},
          'data': [
            {'id': 1, 'name': 'Jakarta'},
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
        },
      });

      final page = await PosRepositoryImpl(api).areaList();
      expect(page.items.single.name, 'Jakarta');
      expect(page.baseUrl, 'https://cdn.test/');
      expect(page.totalPages, 1);
    },
  );

  test('merchantList sends the documented query parameters', () async {
    final api = FakeApiClient({
      'pos/merchant/list': {'status': '200', 'data': []},
    });
    final repo = PosRepositoryImpl(api);

    await repo.merchantList(size: 25, keyword: 'kopi');

    expect(api.lastPath, 'pos/merchant/list');
    expect(api.lastQuery, containsPair('size', 25));
    expect(api.lastQuery, containsPair('keyword', 'kopi'));
  });

  test('merchantList omits keyword from the query when not given', () async {
    final api = FakeApiClient({
      'pos/merchant/list': {'status': '200', 'data': []},
    });

    await PosRepositoryImpl(api).merchantList();

    expect(api.lastQuery, containsPair('size', 100));
    expect(api.lastQuery, isNot(contains('keyword')));
  });

  test(
    'merchantList maps the envelope into a PagedResult<PosMerchantSummary>',
    () async {
      final api = FakeApiClient({
        'pos/merchant/list': {
          'status': '200',
          'meta': {'baseUrl': 'https://cdn.test/'},
          'data': [
            {
              'id': 7,
              'name': 'Kopi Kenangan',
              'address': 'Jl. Sudirman',
              'areaId': 1,
              'areaName': 'Jakarta',
              'logoUrl': '/img/logo.png',
            },
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
        },
      });

      final page = await PosRepositoryImpl(api).merchantList();
      final merchant = page.items.single;
      expect(merchant.id, 7);
      expect(merchant.name, 'Kopi Kenangan');
      expect(merchant.areaName, 'Jakarta');
      expect(page.baseUrl, 'https://cdn.test/');
    },
  );

  test('merchantsByArea always sends areaId in the query', () async {
    final api = FakeApiClient({
      'pos/merchant/area/list': {'status': '200', 'data': []},
    });
    final repo = PosRepositoryImpl(api);

    await repo.merchantsByArea(areaId: 4);

    expect(api.lastPath, 'pos/merchant/area/list');
    expect(api.lastQuery, containsPair('areaId', 4));
    expect(api.lastQuery, containsPair('size', 100));
    expect(api.lastQuery, isNot(contains('keyword')));
  });

  test('merchantsByArea sends size and keyword alongside areaId', () async {
    final api = FakeApiClient({
      'pos/merchant/area/list': {'status': '200', 'data': []},
    });
    final repo = PosRepositoryImpl(api);

    await repo.merchantsByArea(areaId: 4, size: 10, keyword: 'kenangan');

    expect(api.lastQuery, containsPair('areaId', 4));
    expect(api.lastQuery, containsPair('size', 10));
    expect(api.lastQuery, containsPair('keyword', 'kenangan'));
  });

  test(
    'merchantsByArea maps the envelope into a PagedResult<PosMerchantSummary>',
    () async {
      final api = FakeApiClient({
        'pos/merchant/area/list': {
          'status': '200',
          'data': [
            {'id': 7, 'name': 'Kopi Kenangan', 'areaId': 4},
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
        },
      });

      final page = await PosRepositoryImpl(api).merchantsByArea(areaId: 4);
      expect(page.items.single.areaId, 4);
    },
  );

  group('PosArea', () {
    test('tolerates the loose typing the backend sends', () {
      final area = PosArea.fromJson(const {'id': '1', 'name': 'Jakarta'});
      expect(area.id, 1);
      expect(area.name, 'Jakarta');
    });

    test('round-trips through json', () {
      const area = PosArea(id: 2, name: 'Bandung');
      expect(PosArea.fromJson(area.toJson()), area);
    });
  });

  group('PosMerchantSummary', () {
    test('tolerates the loose typing the backend sends', () {
      final merchant = PosMerchantSummary.fromJson(const {
        'id': '7', // string, not number
        'name': 'Kopi Kenangan',
        'areaId': '1', // string, not number
        'areaName': 'Jakarta',
      });
      expect(merchant.id, 7);
      expect(merchant.areaId, 1);
      expect(merchant.name, 'Kopi Kenangan');
    });

    test('parses optional fields as null when absent', () {
      final merchant = PosMerchantSummary.fromJson(const {
        'id': 7,
        'name': 'Kopi Kenangan',
      });
      expect(merchant.address, isNull);
      expect(merchant.areaId, isNull);
      expect(merchant.areaName, isNull);
      expect(merchant.logoUrl, isNull);
    });

    test('round-trips through json', () {
      const merchant = PosMerchantSummary(
        id: 7,
        name: 'Kopi Kenangan',
        address: 'Jl. Sudirman',
        areaId: 1,
        areaName: 'Jakarta',
        logoUrl: '/img/logo.png',
      );
      expect(PosMerchantSummary.fromJson(merchant.toJson()), merchant);
    });
  });
}
