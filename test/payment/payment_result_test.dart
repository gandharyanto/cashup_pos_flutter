import 'package:cashup_pos/src/payment/payment_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('success carries a reference and reports isSuccess', () {
    const result = PosPaymentResult.success(
      reference: 'REF-1',
      approvalCode: '00',
    );
    expect(result.isSuccess, isTrue);
    expect(result.isCancelled, isFalse);
    expect(result.reference, 'REF-1');
  });

  test('cancelled is neither success nor an error to report', () {
    const result = PosPaymentResult.cancelled();
    expect(result.isSuccess, isFalse);
    expect(result.isCancelled, isTrue);
  });

  test('failed carries the message the UI shows', () {
    const result = PosPaymentResult.failed(
      message: 'Kartu ditolak',
      code: '05',
    );
    expect(result.isSuccess, isFalse);
    expect(result.message, 'Kartu ditolak');
  });
}
