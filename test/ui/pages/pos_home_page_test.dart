import 'package:cashup_pos/src/ui/pages/pos_home_page.dart';
import 'package:cashup_pos/src/ui/pages/simple_amount_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPosHome(WidgetTester tester) => tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: PosHomePage())),
  );

  testWidgets('phone width shows one pane and a cart bar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpPosHome(tester);

    expect(find.byType(ProductBrowsePane), findsOneWidget);
    expect(find.byType(CartPane), findsNothing);
    expect(find.byType(CartSummaryBar), findsOneWidget);
  });

  testWidgets('tablet width shows the browse and cart panes side by side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpPosHome(tester);

    expect(find.byType(ProductBrowsePane), findsOneWidget);
    expect(find.byType(CartPane), findsOneWidget);
    expect(find.byType(CartSummaryBar), findsNothing);
  });

  testWidgets('switching to Simple replaces the browse pane', (tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await pumpPosHome(tester);
    await tester.tap(find.text('Simple'));
    await tester.pumpAndSettle();

    expect(find.byType(SimpleAmountPane), findsOneWidget);
    expect(find.byType(ProductBrowsePane), findsNothing);
  });
}
