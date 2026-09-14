import 'package:cashup_pos/src/data/pos_repository_impl.dart';
import 'package:cashup_pos/src/models/create_transaction_request.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api_client.dart'; // records paths, returns canned bodies

/// A minimal, valid `pos/transaction/create` payload — only the fields the
/// repository test needs to exercise are populated.
CreateTransactionRequest sampleRequest() => const CreateTransactionRequest(
  paymentMethod: 'CASH',
  subTotal: '10000.00',
  totalServiceCharge: '0.00',
  totalTax: '0.00',
  totalRounding: '0.00',
  totalAmount: '10000.00',
  transactionItems: [
    RequestTransactionItem(
      productId: 1,
      price: '10000.00',
      qty: 1,
      totalPrice: '10000.00',
    ),
  ],
);

void main() {
  test('productList sends the documented query parameters', () async {
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

  test(
    'productList maps the envelope into a PagedResult with the meta base url',
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

  test('transactionCreate returns the created id and trx id', () async {
    final api = FakeApiClient({
      'pos/transaction/create': {
        'status': '200',
        'message': 'ok',
        'data': {'id': 91, 'trxId': 'TRX-91', 'queueNumber': '4'},
      },
    });

    final created = await PosRepositoryImpl(api)
        .transactionCreate(sampleRequest());
    expect(created.id, 91);
    expect(created.trxId, 'TRX-91');
    expect(created.queueNumber, '4');
  });
}
