import 'package:cashup_pos/src/ui/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the upper-cased status text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StatusBadge('paid'))),
    );

    expect(find.text('PAID'), findsOneWidget);
  });

  testWidgets('renders an unrecognised status as-is rather than throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StatusBadge('refunded'))),
    );

    expect(find.text('REFUNDED'), findsOneWidget);
  });
}
