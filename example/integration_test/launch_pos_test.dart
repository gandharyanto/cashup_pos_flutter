// Runs the SDK-owned application on a device:
//
//   cd example && flutter test integration_test -d <device-id>
import 'package:cashup_pos/cashup_pos.dart';
import 'package:cashup_pos_example/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(CashupPos.dispose);

  testWidgets('launch opens the SDK POS shell directly', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(CashupPos.isInitialized, isTrue);
    expect(find.byTooltip('Menu POS'), findsOneWidget);
  });

  testWidgets('nested SDK routes stay inside the SDK provider scope', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Menu POS'));
    await tester.pumpAndSettle();

    expect(find.text('Segarkan katalog'), findsOneWidget);
  });
}
