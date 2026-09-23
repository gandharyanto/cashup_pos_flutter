import 'package:cashup_pos/src/ui/widgets/qty_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('increments and decrements within bounds', (tester) async {
    var value = 1;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: QtyStepper(
                value: value,
                min: 1,
                max: 3,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          );
        },
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(value, 2);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(value, 1);

    // At the minimum the decrement is disabled, not merely ignored.
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(value, 1);
  });

  testWidgets('does not exceed max', (tester) async {
    var value = 3;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: QtyStepper(
                value: value,
                max: 3,
                onChanged: (n) => setState(() => value = n),
              ),
            ),
          );
        },
      ),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(value, 3);
  });

  testWidgets('the decrement button is disabled at min, not just inert', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QtyStepper(value: 1, min: 1, onChanged: (_) {})),
      ),
    );

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.remove),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('onEditRequested fires when the label is tapped', (tester) async {
    var editRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QtyStepper(
            value: 4,
            onChanged: (_) {},
            onEditRequested: () => editRequested = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('4'));
    await tester.pump();
    expect(editRequested, isTrue);
  });
}
