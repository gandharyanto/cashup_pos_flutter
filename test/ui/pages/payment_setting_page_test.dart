import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:cashup_pos/src/ui/pages/payment_setting_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service charge percentage and amount are mutually exclusive', () {
    const initial = PaymentSetting.defaults();
    final percentage = applyServiceCharge(
      initial,
      mode: ServiceChargeMode.percentage,
      value: 7.5,
    );
    expect(percentage.serviceChargePercentage, 7.5);
    expect(percentage.serviceChargeAmount, 0);
    expect(percentage.isServiceCharge, isTrue);

    final amount = applyServiceCharge(
      percentage,
      mode: ServiceChargeMode.amount,
      value: 5000,
    );
    expect(amount.serviceChargePercentage, 0);
    expect(amount.serviceChargeAmount, 5000);
  });
}
