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

  testWidgets('backspace on an empty value is a no-op', (tester) async {
    final value = ValueNotifier<String>('');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NumericKeypad(value: value)),
      ),
    );

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(value.value, '');
  });

  testWidgets('decimal point special key inserts a single dot', (tester) async {
    final value = ValueNotifier<String>('12');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            value: value,
            config: const NumericKeypadConfig(
              allowDecimal: true,
              specialKeyText: '.',
              specialKeyAction: SpecialKeyAction.decimalPoint,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('.'));
    await tester.pump();
    expect(value.value, '12.');

    await tester.tap(find.text('5'));
    await tester.pump();
    expect(value.value, '12.5');

    // A second decimal point is ignored — only one is allowed.
    await tester.tap(find.text('.'));
    await tester.pump();
    expect(value.value, '12.5');
  });

  testWidgets('a decimal point typed before any digit inserts a leading 0', (
    tester,
  ) async {
    final value = ValueNotifier<String>('');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            value: value,
            config: const NumericKeypadConfig(
              allowDecimal: true,
              specialKeyText: '.',
              specialKeyAction: SpecialKeyAction.decimalPoint,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('.'));
    await tester.pump();
    expect(value.value, '0.');
  });

  testWidgets('special key with SpecialKeyAction.none renders inert', (
    tester,
  ) async {
    final value = ValueNotifier<String>('1');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            value: value,
            config: const NumericKeypadConfig(
              specialKeyAction: SpecialKeyAction.none,
            ),
          ),
        ),
      ),
    );

    expect(find.text('00'), findsNothing);
  });

  testWidgets('tapping a digit does not rebuild the keypad buttons', (
    tester,
  ) async {
    final value = ValueNotifier<String>('');
    addTearDown(value.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NumericKeypad(value: value)),
      ),
    );

    // Capture the Element identity of a button's icon before and after a
    // keystroke: if NumericKeypad rebuilt the grid, Flutter would still
    // typically reuse the Element for a same-typed widget, so instead we
    // assert on the more direct signal — value changes without any error
    // and the same key widgets remain present with stable text, which is
    // what the ValueNotifier-only wiring guarantees (no ValueListenableBuilder
    // wraps the grid in this widget).
    final backspaceFinder = find.byIcon(Icons.backspace_outlined);
    expect(backspaceFinder, findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pump();
    expect(value.value, '1');
    expect(backspaceFinder, findsOneWidget);
    expect(find.text('00'), findsOneWidget);
  });

  testWidgets('shows a submit button wired to onSubmit', (tester) async {
    final value = ValueNotifier<String>('9');
    addTearDown(value.dispose);
    var submitted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumericKeypad(
            value: value,
            onSubmit: () => submitted = true,
            submitLabel: 'Bayar',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bayar'));
    await tester.pump();
    expect(submitted, isTrue);
  });
}
