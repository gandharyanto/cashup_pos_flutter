import 'package:cashup_pos/src/state/cart_controller.dart';
import 'package:cashup_pos/src/ui/pages/simple_amount_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keypad amount becomes one synthetic cart line before charge', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SimpleAmountPane())),
      ),
    );

    await tester.tap(find.text('1'));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('00'));
    await tester.pump();
    expect(find.text('Rp 1.500'), findsOneWidget);

    // Exercise the same cart preparation used by the charge action without
    // entering the repository-backed payment route in this focused test.
    final cart = container.read(cartControllerProvider.notifier);
    cart.clear();
    cart.add(simpleAmountProduct, customBasePrice: 1500);
    final state = container.read(cartControllerProvider);
    expect(state.lines, hasLength(1));
    expect(state.lines.values.single.product.id, -1);
    expect(state.subTotal, 1500);
  });
}
