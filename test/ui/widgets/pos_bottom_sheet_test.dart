import 'package:cashup_pos/src/ui/widgets/pos_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the title and builder content, resolves on pop', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showPosBottomSheet<String>(
                  context,
                  title: 'Pilih opsi',
                  builder: (sheetContext) => ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop('picked'),
                    child: const Text('pilih'),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih opsi'), findsOneWidget);

    await tester.tap(find.text('pilih'));
    await tester.pumpAndSettle();

    expect(result, 'picked');
  });

  testWidgets('the close button dismisses the sheet with a null result', (
    tester,
  ) async {
    String? result = 'unset';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showPosBottomSheet<String>(
                  context,
                  title: 'Pilih opsi',
                  builder: (_) => const Text('konten'),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
