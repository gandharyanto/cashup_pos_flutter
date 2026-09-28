import 'package:cashup_pos/src/ui/widgets/numeric_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('appends digits, honours the 00 key and backspace', (
    tester,
  ) async {
    final value = ValueNotifier<String>('');
    addTearDown(value.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NumericKeypad(value: value)),
      ),
    );

    await tester.tap(find.text('5'));
    await tester.pump();
    expect(value.value, '5');

    await tester.tap(find.text('00'));
    await tester.pump();
    expect(value.value, '500');

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(value.value, '50');
  });

  testWidgets('normalises a leading zero', (tester) async {
    final value = ValueNotifier<String>('0');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NumericKeypad(value: value)),
      ),
    );

    await tester.tap(find.text('7'));
    await tester.pump();
    expect(value.value, '7');
  });

  testWidgets('stops at maxLength', (tester) async {
    final value = ValueNotifier<String>('12');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            value: value,
            config: const NumericKeypadConfig(maxLength: 2),
          ),
        ),
      ),
    );
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(value.value, '12');
  });
}
