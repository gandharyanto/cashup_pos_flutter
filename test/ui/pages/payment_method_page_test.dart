import 'package:cashup_pos/src/ui/pages/payment_method_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cash predictions are unique, ascending-enough and always four', () {
    expect(cashQuickAmounts(18600), [18600, 19000, 20000, 50000]);
    expect(cashQuickAmounts(100000), hasLength(4));
  });

  testWidgets('cash confirmation stays disabled until tendered covers total', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CashPaymentDialog(total: 18000))),
    );
    FilledButton button() =>
        tester.widget(find.widgetWithText(FilledButton, 'Konfirmasi'));
    expect(button().onPressed, isNull);

    await tester.tap(find.text('Rp 18.000').last);
    await tester.pump();
    expect(button().onPressed, isNotNull);
    expect(find.text('Kembalian Rp 0,00'), findsOneWidget);
  });
}
