import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pos_exception.dart';
import '../models/transaction_details.dart';
import 'cart_controller.dart';
import 'checkout_controller.dart';
import 'pos_providers.dart';

enum PaymentFlowStatus { idle, processing, succeeded, failed, indeterminate }

class PaymentFlowState {
  const PaymentFlowState({
    this.status = PaymentFlowStatus.idle,
    this.transaction,
    this.message,
  });
  final PaymentFlowStatus status;
  final CreatedTransaction? transaction;
  final String? message;
}

class PaymentController extends Notifier<PaymentFlowState> {
  @override
  PaymentFlowState build() => const PaymentFlowState();

  Future<CreatedTransaction?> process({
    required String method,
    String cashTendered = '0',
    String cashChange = '0',
    int? queueNumber,
    String? notes,
  }) async {
    if (state.status == PaymentFlowStatus.processing) return null;
    state = const PaymentFlowState(status: PaymentFlowStatus.processing);
    final config = ref.read(posConfigProvider);
    final merchantTrxId = 'POS-${DateTime.now().microsecondsSinceEpoch}';
    try {
      if (method.toUpperCase() != 'CASH' && method.toUpperCase() != 'QRIS') {
        final handler = config.paymentHandler;
        if (handler == null || !handler.supportedMethods.contains(method)) {
          state = const PaymentFlowState(
            status: PaymentFlowStatus.failed,
            message: 'Metode pembayaran tidak didukung.',
          );
          return null;
        }
        final payment = await handler.pay(
          method: method,
          amount: ref.read(checkoutControllerProvider).result.totalAmount,
          merchantTrxId: merchantTrxId,
        );
        if (!payment.isSuccess) {
          state = PaymentFlowState(
            status: PaymentFlowStatus.failed,
            message: payment.isCancelled
                ? 'Pembayaran dibatalkan.'
                : (payment.message ?? 'Pembayaran gagal.'),
          );
          return null;
        }
      }
      ref.read(checkoutControllerProvider.notifier).setPaymentMethod(method);
      final payload = ref
          .read(checkoutControllerProvider.notifier)
          .buildPayload(
            cashTendered: cashTendered,
            cashChange: cashChange,
            queueNumber: queueNumber,
            notes: notes,
          );
      final created = await ref
          .read(posRepositoryProvider)
          .transactionCreate(payload);
      ref.read(cartControllerProvider.notifier).clear();
      state = PaymentFlowState(
        status: PaymentFlowStatus.succeeded,
        transaction: created,
      );
      try {
        final details = await ref
            .read(posRepositoryProvider)
            .transactionDetail(created.id);
        config.onTransactionCompleted?.call(details);
      } catch (_) {
        // Creation already succeeded; receipt-detail fetch failure must not
        // turn a settled sale into a failed payment.
      }
      return created;
    } on PosException catch (error) {
      final uncertain =
          error.kind == PosErrorKind.network ||
          error.kind == PosErrorKind.timeout;
      state = PaymentFlowState(
        status: uncertain
            ? PaymentFlowStatus.indeterminate
            : PaymentFlowStatus.failed,
        message: uncertain
            ? 'Status transaksi belum diketahui. Periksa daftar transaksi sebelum mencoba lagi.'
            : error.friendlyMessage,
      );
      return null;
    } catch (error) {
      state = PaymentFlowState(
        status: PaymentFlowStatus.failed,
        message: error.toString(),
      );
      return null;
    }
  }
}

final paymentControllerProvider =
    NotifierProvider<PaymentController, PaymentFlowState>(
      PaymentController.new,
    );
