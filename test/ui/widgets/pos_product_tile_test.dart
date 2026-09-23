import 'package:cashup_pos/src/ui/widgets/pos_product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows name, price and the cart quantity badge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosProductTile(
            name: 'Kopi Susu',
            price: 18000,
            layout: ProductTileLayout.grid,
            quantityInCart: 2,
          ),
        ),
      ),
    );

    expect(find.text('Kopi Susu'), findsOneWidget);
    expect(find.text('Rp 18.000'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('disables the tap target when out of stock', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosProductTile(
            name: 'Teh',
            price: 8000,
            layout: ProductTileLayout.grid,
            outOfStock: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Teh'));
    expect(tapped, isFalse);
    expect(find.text('Stok habis'), findsOneWidget);
  });

  testWidgets('is wrapped in a RepaintBoundary', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosProductTile(
            name: 'Teh',
            price: 8000,
            layout: ProductTileLayout.grid,
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(PosProductTile),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });
}
