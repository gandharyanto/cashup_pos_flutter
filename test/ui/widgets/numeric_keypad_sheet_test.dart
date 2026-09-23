import 'package:cashup_pos/src/ui/widgets/numeric_keypad_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resolves with the entered value on submit', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showNumericKeypadSheet(
                  context,
                  title: 'Masukkan jumlah',
                  initialValue: '5',
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

    expect(find.text('5'), findsWidgets);

    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('50'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(result, '50');
  });
}
