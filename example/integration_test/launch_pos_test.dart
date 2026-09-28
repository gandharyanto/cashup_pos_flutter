// Runs the real demo app on a device and taps through to the POS shell:
//
//   cd example && flutter test integration_test -d <device-id>
import 'package:cashup_pos/cashup_pos.dart';
import 'package:cashup_pos_example/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(CashupPos.dispose);

  Future<void> openPosShell(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buka POS'));
    // The catalogue request goes to the placeholder backend and fails;
    // give it time to settle into the SDK's offline error state.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    for (var i = 0; i < 50 && find.text('Coba Lagi').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('tapping "Buka POS" opens the SDK POS shell', (tester) async {
    expect(CashupPos.isInitialized, isFalse);

    await openPosShell(tester);

    expect(CashupPos.isInitialized, isTrue);
    expect(find.byTooltip('Menu POS'), findsOneWidget);
    // No backend is reachable at the placeholder URL: the shell shows the
    // pure-online error state with a retry action instead of a catalogue.
    expect(find.text('Coba Lagi'), findsWidgets);
  });

  testWidgets(
    'the POS menu opens from the shell',
    (tester) async {
      await openPosShell(tester);

      await tester.tap(find.byTooltip('Menu POS'));
      await tester.pumpAndSettle();

      expect(find.text('Segarkan katalog'), findsOneWidget);
    },
    // Known SDK defect: routes pushed from inside SDK pages (menu, cart
    // sheet, checkout, dialogs) are built under the host's Navigator,
    // outside CashupPosLauncher's UncontrolledProviderScope, and throw
    // "No ProviderScope found". Un-skip once the launcher scopes nested
    // routes.
    skip: true,
  );
}
