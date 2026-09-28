import 'package:cashup_pos/src/ui/widgets/date_range_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a placeholder when no range is selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateRangeField(
            start: null,
            end: null,
            onChanged: (start, end) {},
          ),
        ),
      ),
    );

    expect(find.text('Pilih tanggal'), findsOneWidget);
  });

  testWidgets('formats a selected range through PosDates', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateRangeField(
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 10),
            onChanged: (start, end) {},
            label: 'Periode',
          ),
        ),
      ),
    );

    expect(find.text('01 Sep 2026 – 10 Sep 2026'), findsOneWidget);
    expect(find.text('Periode'), findsOneWidget);
  });
}
