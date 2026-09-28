import 'package:cashup_pos/src/data/pos_exception.dart';
import 'package:cashup_pos/src/data/pos_repository_impl.dart';
import 'package:cashup_pos/src/models/pos_area.dart';
import 'package:cashup_pos/src/models/pos_merchant_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api_client.dart'; // records paths, returns canned bodies

void main() {
  test('areaList sends the documented query parameters', () async {
    final api = FakeApiClient({
      'pos/area/list': {'success': true, 'data': []},
    });
    final repo = PosRepositoryImpl(api);

    await repo.areaList(size: 50, keyword: 'jak');

    expect(api.lastPath, 'pos/area/list');
    expect(api.lastQuery, containsPair('size', 50));
    expect(api.lastQuery, containsPair('keyword', 'jak'));
  });

  test('areaList omits keyword from the query when not given', () async {
    final api = FakeApiClient({
      'pos/area/list': {'success': true, 'data': []},
    });

    await PosRepositoryImpl(api).areaList();

    expect(api.lastQuery, containsPair('size', 100));
    expect(api.lastQuery, isNot(contains('keyword')));
  });

  test('areaList maps the envelope into a PosLookupPage<PosArea>', () async {
    final api = FakeApiClient({
      'pos/area/list': {
        'success': true,
        'data': [
          {'value': 16461, 'label': 'TOKYO WET'},
        ],
        'pagination': {'page': 5, 'limit': 10, 'hasMore': true},
      },
    });

    final page = await PosRepositoryImpl(api).areaList();
    expect(page.items.single.id, 16461);
    expect(page.items.single.name, 'TOKYO WET');
    expect(page.page, 5);
    expect(page.limit, 10);
    expect(page.hasMore, isTrue);
  });

  test('areaList throws PosException when the envelope reports failure', () {
    final api = FakeApiClient({
      'pos/area/list': {'success': false, 'message': 'Nope'},
    });

    expect(
      () => PosRepositoryImpl(api).areaList(),
      throwsA(isA<PosException>().having((e) => e.message, 'message', 'Nope')),
    );
  });

  test('merchantList sends the documented query parameters', () async {
    final api = FakeApiClient({
      'pos/merchant/list': {'success': true, 'data': []},
    });
    final repo = PosRepositoryImpl(api);

    await repo.merchantList(size: 25, keyword: 'kopi');

    expect(api.lastPath, 'pos/merchant/list');
    expect(api.lastQuery, containsPair('size', 25));
    expect(api.lastQuery, containsPair('keyword', 'kopi'));
  });

  test('merchantList omits keyword from the query when not given', () async {
    final api = FakeApiClient({
      'pos/merchant/list': {'success': true, 'data': []},
    });

    await PosRepositoryImpl(api).merchantList();

    expect(api.lastQuery, containsPair('size', 100));
    expect(api.lastQuery, isNot(contains('keyword')));
  });

  test(
    'merchantList maps the envelope into a PosLookupPage<PosMerchantSummary>',
    () async {
      final api = FakeApiClient({
        'pos/merchant/list': {
          'success': true,
          'data': [
            {'value': 16461, 'label': 'Misoa Nai Nai (TOKYO WET)'},
            {
              'value': 4895,
              'label': "Mowi'S Chicken (Old Shanghai Sedayu City)",
            },
            {'value': 16445, 'label': 'Nasi Hainam Lee 78 (TOKYO WET)'},
          ],
          'pagination': {'page': 5, 'limit': 10, 'hasMore': true},
        },
      });

      final page = await PosRepositoryImpl(api).merchantList();
      expect(page.items, hasLength(3));
      final merchant = page.items.first;
      expect(merchant.id, 16461);
      expect(merchant.label, 'Misoa Nai Nai (TOKYO WET)');
      expect(merchant.name, 'Misoa Nai Nai');
      expect(merchant.areaName, 'TOKYO WET');
      expect(page.page, 5);
      expect(page.limit, 10);
      expect(page.hasMore, isTrue);
    },
  );

  test(
    'merchantList throws PosException when the envelope reports failure',
    () {
      final api = FakeApiClient({
        'pos/merchant/list': {'success': false, 'message': 'Server down'},
      });

      expect(
        () => PosRepositoryImpl(api).merchantList(),
        throwsA(
          isA<PosException>().having(
            (e) => e.message,
            'message',
            'Server down',
          ),
        ),
      );
    },
  );

  test('merchantsByArea always sends areaId in the query', () async {
    final api = FakeApiClient({
      'pos/merchant/area/list': {'success': true, 'data': []},
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
      'pos/merchant/area/list': {'success': true, 'data': []},
    });
    final repo = PosRepositoryImpl(api);

    await repo.merchantsByArea(areaId: 4, size: 10, keyword: 'kenangan');

    expect(api.lastQuery, containsPair('areaId', 4));
    expect(api.lastQuery, containsPair('size', 10));
    expect(api.lastQuery, containsPair('keyword', 'kenangan'));
  });

  test('merchantsByArea maps the envelope into a PosLookupPage<PosMerchantSummary>', () async {
    final api = FakeApiClient({
      'pos/merchant/area/list': {
        'success': true,
        'data': [
          {'value': 16461, 'label': 'Misoa Nai Nai (TOKYO WET)'},
        ],
        'pagination': {'page': 0, 'limit': 10, 'hasMore': false},
      },
    });

    final page = await PosRepositoryImpl(api).merchantsByArea(areaId: 4);
    expect(page.items.single.id, 16461);
    expect(page.hasMore, isFalse);
  });

  test(
    'merchantsByArea throws PosException when the envelope reports failure',
    () {
      final api = FakeApiClient({
        'pos/merchant/area/list': {'success': false},
      });

      expect(
        () => PosRepositoryImpl(api).merchantsByArea(areaId: 4),
        throwsA(isA<PosException>()),
      );
    },
  );

  group('PosArea', () {
    test('reads the wire\'s value/label keys', () {
      final area = PosArea.fromJson(const {'value': 1, 'label': 'Jakarta'});
      expect(area.id, 1);
      expect(area.name, 'Jakarta');
    });

    test('tolerates the loose typing the backend sends', () {
      final area = PosArea.fromJson(const {'value': '1', 'label': 'Jakarta'});
      expect(area.id, 1);
      expect(area.name, 'Jakarta');
    });

    test('toJson emits the canonical {id, name} shape, not the wire keys', () {
      const area = PosArea(id: 2, name: 'Bandung');
      expect(area.toJson(), {'id': 2, 'name': 'Bandung'});
    });
  });

  group('PosMerchantSummary', () {
    test('reads the wire\'s value/label keys', () {
      final merchant = PosMerchantSummary.fromJson(const {
        'value': 16461,
        'label': 'Misoa Nai Nai (TOKYO WET)',
      });
      expect(merchant.id, 16461);
      expect(merchant.label, 'Misoa Nai Nai (TOKYO WET)');
    });

    test('tolerates the loose typing the backend sends', () {
      final merchant = PosMerchantSummary.fromJson(const {
        'value': '7', // string, not number
        'label': 'Kopi Kenangan',
      });
      expect(merchant.id, 7);
      expect(merchant.label, 'Kopi Kenangan');
    });

    test('toJson emits the model\'s own {id, label} shape', () {
      const merchant = PosMerchantSummary(
        id: 7,
        label: 'Kopi Kenangan (Jakarta)',
      );
      expect(merchant.toJson(), {'id': 7, 'label': 'Kopi Kenangan (Jakarta)'});
    });

    test('name/areaName parse a trailing "(Area)" suffix off the label', () {
      const merchant = PosMerchantSummary(
        id: 16461,
        label: 'Misoa Nai Nai (TOKYO WET)',
      );
      expect(merchant.name, 'Misoa Nai Nai');
      expect(merchant.areaName, 'TOKYO WET');
    });

    test('name falls back to the full label when there is no suffix', () {
      const merchant = PosMerchantSummary(id: 1, label: 'Kopi Kenangan');
      expect(merchant.name, 'Kopi Kenangan');
      expect(merchant.areaName, isNull);
    });
  });
}
