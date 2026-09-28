import 'package:cashup_pos/src/ui/widgets/cart_line_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows name, options summary and line total', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CartLineTile(
            name: 'Kopi Susu',
            unitPrice: 18000,
            quantity: 2,
            lineTotal: 36000,
            optionsSummary: 'Besar, Less Sugar',
          ),
        ),
      ),
    );

    expect(find.text('Kopi Susu'), findsOneWidget);
    expect(find.text('Besar, Less Sugar'), findsOneWidget);
    expect(find.text('Rp 36.000'), findsOneWidget);
  });

  testWidgets('reports quantity changes through the stepper', (tester) async {
    var newQuantity = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartLineTile(
            name: 'Kopi Susu',
            unitPrice: 18000,
            quantity: 2,
            lineTotal: 36000,
            onQuantityChanged: (value) => newQuantity = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    expect(newQuantity, 3);
  });

  testWidgets('calls onRemove when the remove button is tapped', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartLineTile(
            name: 'Kopi Susu',
            unitPrice: 18000,
            quantity: 2,
            lineTotal: 36000,
            onRemove: () => removed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });
}
