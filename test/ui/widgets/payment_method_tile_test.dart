import 'package:cashup_pos/src/ui/widgets/payment_method_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows name and subtitle, and reports taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentMethodTile(
            name: 'QRIS',
            code: 'QRIS',
            subtitle: 'Scan untuk bayar',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('QRIS'), findsOneWidget);
    expect(find.text('Scan untuk bayar'), findsOneWidget);

    await tester.tap(find.text('QRIS'));
    expect(tapped, isTrue);
  });

  testWidgets('ignores taps when disabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentMethodTile(
            name: 'Kartu Kredit',
            code: 'CC',
            enabled: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Kartu Kredit'));
    expect(tapped, isFalse);
  });
}
