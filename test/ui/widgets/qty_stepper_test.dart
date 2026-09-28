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
}
