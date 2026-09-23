import 'package:cashup_pos/src/ui/widgets/category_chip_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the all chip selected when selectedId is null', (
    tester,
  ) async {
    int? selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChipBar(
            categories: const [
              (id: 1, name: 'Minuman'),
              (id: 2, name: 'Makanan'),
            ],
            selectedId: null,
            onSelected: (id) => selected = id,
          ),
        ),
      ),
    );

    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Minuman'), findsOneWidget);
    expect(find.text('Makanan'), findsOneWidget);

    final allChip = tester.widget<ChoiceChip>(
      find.ancestor(of: find.text('Semua'), matching: find.byType(ChoiceChip)),
    );
    expect(allChip.selected, isTrue);

    await tester.tap(find.text('Makanan'));
    expect(selected, 2);
  });
}
