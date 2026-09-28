import 'package:cashup_pos/cashup_pos.dart';

/// A stand-in for the host's real card / EDC integration.
///
/// A production host would drive its card reader or EDC terminal here and
/// translate the terminal's response into a [PosPaymentResult]. This demo
/// simply waits a moment and approves every payment, so the checkout flow
/// can be walked through without any hardware.
class DemoPaymentHandler implements PosPaymentHandler {
  const DemoPaymentHandler({this.delay = const Duration(seconds: 2)});

  /// How long the simulated terminal "thinks" before approving.
  final Duration delay;

  /// Only payment methods whose backend code appears here are offered at
  /// checkout — cash is always available, QRIS depends on `QrisGateway`.
  @override
  Set<String> get supportedMethods => const {'CARD'};

  @override
  Future<PosPaymentResult> pay({
    required String method,
    required double amount,
    required String merchantTrxId,
    int? transactionId,
  }) async {
    await Future<void>.delayed(delay);
    return PosPaymentResult.success(
      reference: 'DEMO-$merchantTrxId',
      approvalCode: '123456',
      cardMasked: '4111 **** **** 1111',
      raw: {'method': method, 'amount': amount},
    );
  }
}
