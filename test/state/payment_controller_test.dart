import 'package:cashup_pos/src/config/pos_config.dart';
import 'package:cashup_pos/src/data/pos_exception.dart';
import 'package:cashup_pos/src/models/create_transaction_request.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/models/transaction_details.dart';
import 'package:cashup_pos/src/state/cart_controller.dart';
import 'package:cashup_pos/src/state/payment_controller.dart';
import 'package:cashup_pos/src/state/pos_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/fake_repository.dart';

class FailingCreateRepository extends FakeRepository {
  @override
  Future<CreatedTransaction> transactionCreate(
    CreateTransactionRequest request,
  ) async {
    transactionCreateCalls++;
    throw const PosException(kind: PosErrorKind.timeout, message: 'lost');
  }
}

ProviderContainer containerFor(FakeRepository repository) => ProviderContainer(
  overrides: [
    posRepositoryProvider.overrideWithValue(repository),
    posConfigProvider.overrideWithValue(
      PosConfig(
        baseUrl: 'https://test/',
        tokenProvider: () async => null,
        merchant: const PosMerchant(name: 'Test'),
      ),
    ),
  ],
);

void main() {
  test('cash creation clears cart only after backend success', () async {
    final repository = FakeRepository()
      ..transactionCreateResult = const CreatedTransaction(id: 2, trxId: 'T2');
    final container = containerFor(repository);
    addTearDown(container.dispose);
    container
        .read(cartControllerProvider.notifier)
        .add(
          const PosProduct(
            id: 1,
            name: 'Kopi',
            basePrice: 10000,
            isUnlimitedStock: true,
          ),
        );

    final result = await container
        .read(paymentControllerProvider.notifier)
        .process(method: 'CASH');

    expect(result?.trxId, 'T2');
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
    expect(repository.transactionCreateCalls, 1);
  });

  test(
    'lost create response is indeterminate and never auto-retried',
    () async {
      final repository = FailingCreateRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      container
          .read(cartControllerProvider.notifier)
          .add(
            const PosProduct(
              id: 1,
              name: 'Kopi',
              basePrice: 10000,
              isUnlimitedStock: true,
            ),
          );

      await container
          .read(paymentControllerProvider.notifier)
          .process(method: 'CASH');

      expect(
        container.read(paymentControllerProvider).status,
        PaymentFlowStatus.indeterminate,
      );
      expect(repository.transactionCreateCalls, 1);
      expect(container.read(cartControllerProvider).isEmpty, isFalse);
    },
  );
}
