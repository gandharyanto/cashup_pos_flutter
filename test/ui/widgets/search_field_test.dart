import 'package:cashup_pos/src/ui/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('debounces onChanged so only the last value within the '
      'window is reported', (tester) async {
    final reported = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchField(
            debounce: const Duration(milliseconds: 50),
            onChanged: reported.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 10));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 10));
    await tester.enterText(find.byType(TextField), 'abc');

    expect(reported, isEmpty);

    await tester.pump(const Duration(milliseconds: 80));
    expect(reported, ['abc']);
  });

  testWidgets('shows initialValue and a clear button that resets it', (
    tester,
  ) async {
    var lastValue = 'unset';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchField(
            initialValue: 'kopi',
            onChanged: (v) => lastValue = v,
          ),
        ),
      ),
    );

    expect(find.text('kopi'), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(find.text('kopi'), findsNothing);
    expect(lastValue, '');
  });

  testWidgets('hides the clear button when the field is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SearchField(onChanged: (_) {})),
      ),
    );

    expect(find.byIcon(Icons.clear), findsNothing);
  });
}
