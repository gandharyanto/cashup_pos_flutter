import 'package:cashup_pos/src/ui/widgets/pos_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders title, child and actions; close invokes onClose', (
    tester,
  ) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PosDialog(
                  title: 'Konfirmasi',
                  onClose: () => closed = true,
                  actions: const [Text('Batal'), Text('OK')],
                  child: const Text('Isi dialog'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi'), findsOneWidget);
    expect(find.text('Isi dialog'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(closed, isTrue);
  });
}
