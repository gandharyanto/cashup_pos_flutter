import 'package:cashup_pos/src/ui/widgets/amount_row.dart';
import 'package:cashup_pos/src/ui/widgets/totals_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders each row with rupiah formatting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TotalsPanel(
            rows: [
              AmountRow(label: 'Subtotal', amount: 36000),
              AmountRow(label: 'Diskon', amount: 5000, negative: true),
              AmountRow(
                label: 'TOTAL',
                amount: 31000,
                emphasis: AmountEmphasis.total,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Rp 36.000'), findsOneWidget);
    expect(find.text('-Rp 5.000'), findsOneWidget);
    expect(find.text('Rp 31.000'), findsOneWidget);
  });
}
