import 'package:cashup_pos/src/ui/widgets/option_group_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sizeGroup = (
    id: 1,
    name: 'Ukuran',
    multiSelect: false,
    min: 1,
    max: 1,
    options: [
      (id: 11, name: 'Kecil', priceDelta: 0.0),
      (id: 12, name: 'Besar', priceDelta: 5000.0),
    ],
  );

  const toppingGroup = (
    id: 2,
    name: 'Topping',
    multiSelect: true,
    min: 0,
    max: 1,
    options: [
      (id: 21, name: 'Boba', priceDelta: 3000.0),
      (id: 22, name: 'Jelly', priceDelta: 3000.0),
    ],
  );

  testWidgets('selecting a radio option replaces the group selection', (
    tester,
  ) async {
    List<OptionGroupSelection>? updated;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptionGroupSelector(
            groups: [sizeGroup],
            selections: const [
              OptionGroupSelection(groupId: 1, optionIds: [11]),
            ],
            onChanged: (value) => updated = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Besar'));
    expect(updated, isNotNull);
    expect(updated!.single.groupId, 1);
    expect(updated!.single.optionIds, [12]);
  });

  testWidgets('multi-select group enforces max by disabling extra choices', (
    tester,
  ) async {
    List<OptionGroupSelection>? updated;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptionGroupSelector(
            groups: [toppingGroup],
            selections: const [
              OptionGroupSelection(groupId: 2, optionIds: [21]),
            ],
            onChanged: (value) => updated = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Jelly'));
    expect(updated, isNull);
  });
}
