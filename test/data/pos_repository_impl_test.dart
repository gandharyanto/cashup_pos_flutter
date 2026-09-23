import 'package:cashup_pos/src/data/pos_exception.dart';
import 'package:cashup_pos/src/data/pos_repository.dart';
import 'package:cashup_pos/src/data/pos_repository_impl.dart';
import 'package:cashup_pos/src/models/create_transaction_request.dart';
import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api_client.dart';

CreateTransactionRequest sampleRequest() => const CreateTransactionRequest(
  paymentMethod: 'CASH',
  subTotal: '18000.00',
  totalServiceCharge: '0.00',
  totalTax: '0.00',
  totalRounding: '0.00',
  totalAmount: '18000.00',
  transactionItems: [],
);

void main() {
  // ── Product ──────────────────────────────────────────────────────────

  group('productList', () {
    test('sends the documented query parameters', () async {
      final api = FakeApiClient({
        'pos/product/list': {'status': '200', 'data': []},
      });
      final repo = PosRepositoryImpl(api);

      await repo.productList(size: 50, categoryId: 3, keyword: 'kopi');

      expect(api.lastPath, 'pos/product/list');
      expect(api.lastQuery, containsPair('size', 50));
      expect(api.lastQuery, containsPair('categoryId', 3));
      expect(api.lastQuery, containsPair('keyword', 'kopi'));
    });

    test('omits unset optional query parameters', () async {
      final api = FakeApiClient({
        'pos/product/list': {'status': '200', 'data': []},
      });

      await PosRepositoryImpl(api).productList();

      expect(api.lastQuery, containsPair('size', 100));
      expect(api.lastQuery, isNot(contains('categoryId')));
      expect(api.lastQuery, isNot(contains('keyword')));
      expect(api.lastQuery, isNot(contains('upc')));
      expect(api.lastQuery, isNot(contains('sku')));
      expect(api.lastQuery, isNot(contains('sortBy')));
      expect(api.lastQuery, isNot(contains('sortDir')));
    });

    test(
      'maps the envelope into a PagedResult with the meta base url',
      () async {
        final api = FakeApiClient({
          'pos/product/list': {
            'status': '200',
            'meta': {'baseUrl': 'https://cdn.test/'},
            'data': [
              {'id': 1, 'name': 'Kopi', 'basePrice': 18000},
            ],
            'page': 0,
            'size': 20,
            'totalElements': 1,
            'totalPages': 1,
          },
        });

        final page = await PosRepositoryImpl(api).productList();
        expect(page.items.single.name, 'Kopi');
        expect(page.baseUrl, 'https://cdn.test/');
        expect(page.totalPages, 1);
      },
    );
  });

  group('productDetail', () {
    test('requests the detail path and maps the product', () async {
      final api = FakeApiClient({
        'pos/product/detail/7': {
          'status': '200',
          'data': {'id': 7, 'name': 'Teh Tarik'},
        },
      });

      final product = await PosRepositoryImpl(api).productDetail(7);

      expect(api.lastPath, 'pos/product/detail/7');
      expect(product.id, 7);
      expect(product.name, 'Teh Tarik');
    });

    test('throws badResponse when data is missing', () async {
      final api = FakeApiClient({
        'pos/product/detail/7': {'status': '200'},
      });

      expect(
        () => PosRepositoryImpl(api).productDetail(7),
        throwsA(
          isA<PosException>().having(
            (e) => e.kind,
            'kind',
            PosErrorKind.badResponse,
          ),
        ),
      );
    });
  });

  group('productCreate', () {
    test('posts the draft and returns the new product id', () async {
      final api = FakeApiClient({
        'pos/product/add': {
          'status': '200',
          'data': {'productId': 42, 'name': 'Kopi Susu'},
        },
      });

      final id = await PosRepositoryImpl(api).productCreate(
        const PosProductDraft(name: 'Kopi Susu', price: 18000, qty: 10),
      );

      expect(api.lastPath, 'pos/product/add');
      expect(api.lastBody, {
        'name': 'Kopi Susu',
        'price': 18000.0,
        'sku': '',
        'upc': '',
        'imageUrl': '',
        'imageThumbUrl': '',
        'description': '',
        'qty': 10,
      });
      expect(id, 42);
    });

    test('includes categoryIds only when provided', () async {
      final api = FakeApiClient({
        'pos/product/add': {
          'status': '200',
          'data': {'productId': 1},
        },
      });

      await PosRepositoryImpl(api).productCreate(
        const PosProductDraft(
          name: 'Kopi Susu',
          price: 18000,
          categoryIds: [1, 2],
        ),
      );

      expect((api.lastBody as Map)['categoryIds'], [1, 2]);
    });

    test('throws badResponse when productId is missing', () async {
      final api = FakeApiClient({
        'pos/product/add': {
          'status': '200',
          'data': {'name': 'Kopi Susu'},
        },
      });

      expect(
        () => PosRepositoryImpl(
          api,
        ).productCreate(const PosProductDraft(name: 'Kopi Susu', price: 18000)),
        throwsA(
          isA<PosException>().having(
            (e) => e.kind,
            'kind',
            PosErrorKind.badResponse,
          ),
        ),
      );
    });
  });

  group('productUpdate', () {
    test(
      'puts to the update path with the product id folded into the body',
      () async {
        final api = FakeApiClient({
          'pos/product/update': {'status': '200'},
        });

        await PosRepositoryImpl(api).productUpdate(
          9,
          const PosProductDraft(name: 'Kopi Susu', price: 20000),
        );

        expect(api.lastMethod, 'PUT');
        expect(api.lastPath, 'pos/product/update');
        expect((api.lastBody as Map)['productId'], 9);
        expect((api.lastBody as Map).containsKey('qty'), isFalse);
      },
    );
  });

  group('productDelete', () {
    test('sends DELETE to the product path', () async {
      final api = FakeApiClient({
        'pos/product/delete/5': {'status': '200'},
      });

      await PosRepositoryImpl(api).productDelete(5);

      expect(api.lastMethod, 'DELETE');
      expect(api.lastPath, 'pos/product/delete/5');
    });
  });

  group('productOptionGroups', () {
    test(
      'maps variant and modifier groups from the option-groups endpoint',
      () async {
        final api = FakeApiClient({
          'pos/product/3/option-groups': {
            'status': '200',
            'data': {
              'productId': 3,
              'productType': 'VARIANT',
              'variantGroups': [
                {
                  'groupId': 1,
                  'name': 'Ukuran',
                  'groupType': 'VARIANT',
                  'options': [
                    {'optionId': 1, 'name': 'Small'},
                  ],
                },
              ],
              'modifierGroups': [],
            },
          },
        });

        final groups = await PosRepositoryImpl(api).productOptionGroups(3);

        expect(api.lastPath, 'pos/product/3/option-groups');
        expect(groups, isNotNull);
        expect(groups!.variantGroups.single.name, 'Ukuran');
      },
    );

    test('returns null when the product has no options', () async {
      final api = FakeApiClient({
        'pos/product/3/option-groups': {'status': '200', 'data': null},
      });

      final groups = await PosRepositoryImpl(api).productOptionGroups(3);
      expect(groups, isNull);
    });
  });

  // ── Category ─────────────────────────────────────────────────────────

  group('categoryList', () {
    test('sends the size query parameter and maps categories', () async {
      final api = FakeApiClient({
        'pos/category/list': {
          'status': '200',
          'data': [
            {'id': 1, 'name': 'Minuman'},
          ],
          'totalElements': 1,
          'totalPages': 1,
        },
      });

      final page = await PosRepositoryImpl(api).categoryList(size: 20);

      expect(api.lastPath, 'pos/category/list');
      expect(api.lastQuery, {'size': 20});
      expect(page.items.single.name, 'Minuman');
    });
  });

  group('categoryDetail', () {
    test('requests the detail path and maps the category', () async {
      final api = FakeApiClient({
        'pos/category/detail/4': {
          'status': '200',
          'data': {'id': 4, 'name': 'Makanan'},
        },
      });

      final category = await PosRepositoryImpl(api).categoryDetail(4);

      expect(api.lastPath, 'pos/category/detail/4');
      expect(category.name, 'Makanan');
    });
  });

  group('categoryCreate', () {
    test('posts the draft and returns the new category id', () async {
      final api = FakeApiClient({
        'pos/category/single/add': {
          'status': '200',
          'data': {'categoryId': 11, 'name': 'Minuman'},
        },
      });

      final id = await PosRepositoryImpl(api)
          .categoryCreate(const PosCategoryDraft(name: 'Minuman'));

      expect(api.lastPath, 'pos/category/single/add');
      expect(api.lastBody, {'name': 'Minuman', 'image': '', 'description': ''});
      expect(id, 11);
    });

    test('throws badResponse when categoryId is missing', () async {
      final api = FakeApiClient({
        'pos/category/single/add': {
          'status': '200',
          'data': {'name': 'Minuman'},
        },
      });

      expect(
        () =>
            PosRepositoryImpl(api)
                .categoryCreate(const PosCategoryDraft(name: 'Minuman')),
        throwsA(
          isA<PosException>().having(
            (e) => e.kind,
            'kind',
            PosErrorKind.badResponse,
          ),
        ),
      );
    });
  });

  group('categoryUpdate', () {
    test(
      'puts to the update path with the category id folded into the body',
      () async {
        final api = FakeApiClient({
          'pos/category/update': {'status': '200'},
        });

        await PosRepositoryImpl(api)
            .categoryUpdate(6, const PosCategoryDraft(name: 'Minuman'));

        expect(api.lastMethod, 'PUT');
        expect(api.lastPath, 'pos/category/update');
        expect(api.lastBody, {
          'categoryId': 6,
          'name': 'Minuman',
          'image': '',
          'description': '',
        });
      },
    );
  });

  group('categoryDelete', () {
    test('sends DELETE to the category path', () async {
      final api = FakeApiClient({
        'pos/category/delete/6': {'status': '200'},
      });

      await PosRepositoryImpl(api).categoryDelete(6);

      expect(api.lastMethod, 'DELETE');
      expect(api.lastPath, 'pos/category/delete/6');
    });
  });

  // ── Stock ────────────────────────────────────────────────────────────

  group('stockUpdate', () {
    test('puts the productId/qty/updateType body', () async {
      final api = FakeApiClient({
        'pos/stock/update': {'status': '200'},
      });

      await PosRepositoryImpl(api)
          .stockUpdate(productId: 2, qty: 5, updateType: 'IN');

      expect(api.lastMethod, 'PUT');
      expect(api.lastPath, 'pos/stock/update');
      expect(api.lastBody, {'productId': 2, 'qty': 5, 'updateType': 'IN'});
    });
  });

  group('stockMovements', () {
    test('sends productId and formatted date-range query parameters', () async {
      final api = FakeApiClient({
        'pos/stock-movement/product/list': {
          'status': '200',
          'data': [
            {
              'productId': 2,
              'qty': 5,
              'movementType': 'IN',
              'movementReason': 'Restock',
              'localDateTime': '2026-09-10T10:00:00',
            },
          ],
          'page': 0,
          'size': 1,
          'totalElements': 1,
          'totalPages': 1,
        },
      });

      final page = await PosRepositoryImpl(api).stockMovements(
        productId: 2,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 10),
      );

      expect(api.lastPath, 'pos/stock-movement/product/list');
      expect(api.lastQuery, {
        'productId': 2,
        'startDate': '2026-09-01',
        'endDate': '2026-09-10',
      });
      expect(page.items.single.movementType, 'IN');
    });
  });

  // ── Payment setting & methods ────────────────────────────────────────

  group('paymentSetting', () {
    test('maps the settings envelope', () async {
      final api = FakeApiClient({
        'pos/payment-setting': {
          'status': '200',
          'data': {
            'paymentSettingId': 1,
            'isPriceIncludeTax': true,
            'isRounding': false,
            'roundingTarget': 0,
            'roundingType': 'NONE',
            'isServiceCharge': false,
            'serviceChargePercentage': 0,
            'serviceChargeAmount': 0,
            'isTax': true,
            'taxPercentage': 10,
            'taxName': 'PPN',
          },
        },
      });

      final setting = await PosRepositoryImpl(api).paymentSetting();

      expect(api.lastPath, 'pos/payment-setting');
      expect(setting, isNotNull);
      expect(setting!.taxName, 'PPN');
    });

    test('returns null when the merchant has no settings yet', () async {
      final api = FakeApiClient({
        'pos/payment-setting': {'status': '200', 'data': null},
      });

      final setting = await PosRepositoryImpl(api).paymentSetting();
      expect(setting, isNull);
    });
  });

  group('paymentSettingCreate', () {
    test('posts the setting to the create path', () async {
      final api = FakeApiClient({
        'pos/payment-setting/create': {'status': '200'},
      });

      await PosRepositoryImpl(api).paymentSettingCreate(
        const PaymentSetting(
          paymentSettingId: 0,
          isPriceIncludeTax: false,
          isRounding: false,
          roundingTarget: 0,
          roundingType: 'NONE',
          isServiceCharge: false,
          serviceChargePercentage: 0,
          serviceChargeAmount: 0,
          isTax: false,
          taxPercentage: 0,
          taxName: '',
        ),
      );

      expect(api.lastMethod, 'POST');
      expect(api.lastPath, 'pos/payment-setting/create');
    });
  });

  group('paymentSettingUpdate', () {
    test('puts the setting to the update path', () async {
      final api = FakeApiClient({
        'pos/payment-setting/update': {'status': '200'},
      });

      await PosRepositoryImpl(api).paymentSettingUpdate(
        const PaymentSetting(
          paymentSettingId: 1,
          isPriceIncludeTax: false,
          isRounding: false,
          roundingTarget: 0,
          roundingType: 'NONE',
          isServiceCharge: false,
          serviceChargePercentage: 0,
          serviceChargeAmount: 0,
          isTax: false,
          taxPercentage: 0,
          taxName: '',
        ),
      );

      expect(api.lastMethod, 'PUT');
      expect(api.lastPath, 'pos/payment-setting/update');
      expect((api.lastBody as Map)['paymentSettingId'], 1);
    });
  });

  group('paymentMethods', () {
    test('flattens internal and external payment methods', () async {
      final api = FakeApiClient({
        'pos/payment-method/merchant/list': {
          'status': '200',
          'data': {
            'internalPayments': [
              {'code': 'CASH', 'name': 'Tunai', 'displayOrder': 0},
            ],
            'externalPayments': [
              {'code': 'QRIS', 'name': 'QRIS', 'displayOrder': 1},
            ],
          },
        },
      });

      final methods = await PosRepositoryImpl(api).paymentMethods();

      expect(api.lastPath, 'pos/payment-method/merchant/list');
      expect(methods.map((m) => m.code), ['CASH', 'QRIS']);
    });
  });

  // ── Transaction ──────────────────────────────────────────────────────

  group('transactionCreate', () {
    test('returns the created id and trx id', () async {
      final api = FakeApiClient({
        'pos/transaction/create': {
          'status': '200',
          'message': 'ok',
          'data': {'id': 91, 'trxId': 'TRX-91', 'queueNumber': '4'},
        },
      });

      final created = await PosRepositoryImpl(api)
          .transactionCreate(sampleRequest());

      expect(api.lastMethod, 'POST');
      expect(api.lastPath, 'pos/transaction/create');
      expect(created.id, 91);
      expect(created.trxId, 'TRX-91');
      expect(created.queueNumber, '4');
    });

    test('sends the wire-renamed payload keys', () async {
      final api = FakeApiClient({
        'pos/transaction/create': {
          'status': '200',
          'data': {'id': 1, 'trxId': 'TRX-1'},
        },
      });

      await PosRepositoryImpl(api).transactionCreate(sampleRequest());

      final body = api.lastBody as Map;
      expect(body['grossAmount'], '18000.00');
      expect(body.containsKey('subTotal'), isFalse);
    });
  });

  group('transactionDetail', () {
    test('requests the detail path and maps the transaction', () async {
      final api = FakeApiClient({
        'pos/transaction/detail/91': {
          'status': '200',
          'data': {
            'transactionId': 91,
            'code': 'TRX-91',
            'status': 'PAID',
            'paymentMethod': 'CASH',
            'transactionDate': '2026-09-10T10:00:00',
          },
        },
      });

      final details = await PosRepositoryImpl(api).transactionDetail(91);

      expect(api.lastPath, 'pos/transaction/detail/91');
      expect(details.code, 'TRX-91');
    });
  });

  group('transactionUpdate', () {
    test('puts to the merchant-trx path with the settlement body', () async {
      final api = FakeApiClient({
        'pos/transaction/update/TRX-91': {'status': '200'},
      });

      await PosRepositoryImpl(api).transactionUpdate(
        'TRX-91',
        const UpdateTransactionRequest(
          paymentMethod: 'QRIS',
          amountPaid: 18000,
          status: 'SUCCESS',
          paymentReference: 'REF-1',
          paymentDate: '2026-09-10T10:00:00',
        ),
      );

      expect(api.lastMethod, 'PUT');
      expect(api.lastPath, 'pos/transaction/update/TRX-91');
      expect((api.lastBody as Map)['paymentReference'], 'REF-1');
    });
  });

  group('transactionList', () {
    test('sends paging, date-range and sort query parameters', () async {
      final api = FakeApiClient({
        'pos/transaction/list': {
          'status': '200',
          'data': [
            {'id': 1, 'code': 'TRX-1'},
          ],
          'page': 0,
          'size': 10,
          'totalElements': 1,
          'totalPages': 1,
        },
      });

      final page = await PosRepositoryImpl(api).transactionList(
        page: 0,
        size: 10,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 10),
      );

      expect(api.lastPath, 'pos/transaction/list');
      expect(api.lastQuery, {
        'page': 0,
        'size': 10,
        'startDate': '2026-09-01',
        'endDate': '2026-09-10',
        'sortBy': 'transactionDate',
        'sortType': 'DESC',
      });
      expect(page.items.single.code, 'TRX-1');
    });
  });

  // ── Reports, discounts & promotions ─────────────────────────────────

  group('summaryReport', () {
    test('sends the date-range query parameters and maps the report', () async {
      final api = FakeApiClient({
        'pos/summary-report/list': {
          'status': '200',
          'data': {
            'productList': [
              {'productName': 'Kopi', 'totalSaleItems': 3},
            ],
            'paymentListInternal': [],
            'paymentListExternal': [],
          },
        },
      });

      final report = await PosRepositoryImpl(api).summaryReport(
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 10),
      );

      expect(api.lastPath, 'pos/summary-report/list');
      expect(api.lastQuery, {
        'startDate': '2026-09-01',
        'endDate': '2026-09-10',
      });
      expect(report.productList.single.productName, 'Kopi');
    });
  });

  group('discountList', () {
    test('maps the bare data array', () async {
      final api = FakeApiClient({
        'pos/discount/available': {
          'status': '200',
          'data': [
            {
              'id': 1,
              'name': 'Diskon Ulang Tahun',
              'valueType': 'PERCENTAGE',
              'value': 10,
              'scope': 'ALL',
            },
          ],
        },
      });

      final discounts = await PosRepositoryImpl(api).discountList();

      expect(api.lastPath, 'pos/discount/available');
      expect(discounts.single.name, 'Diskon Ulang Tahun');
    });

    test('returns an empty list when data is absent', () async {
      final api = FakeApiClient({
        'pos/discount/available': {'status': '200'},
      });

      final discounts = await PosRepositoryImpl(api).discountList();
      expect(discounts, isEmpty);
    });
  });

  group('activePromotions', () {
    test('maps the bare data array', () async {
      final api = FakeApiClient({
        'pos/promotion/active': {
          'status': '200',
          'data': [
            {'id': 1, 'name': 'Beli 2 Gratis 1', 'promoType': 'BUY_X_GET_Y'},
          ],
        },
      });

      final promotions = await PosRepositoryImpl(api).activePromotions();

      expect(api.lastPath, 'pos/promotion/active');
      expect(promotions.single.name, 'Beli 2 Gratis 1');
    });
  });
}
