import 'package:cashup_pos/src/util/debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('only the last action within the window runs', (tester) async {
    final debouncer = Debouncer(duration: const Duration(milliseconds: 50));
    addTearDown(debouncer.dispose);

    final calls = <int>[];
    debouncer.run(() => calls.add(1));
    debouncer.run(() => calls.add(2));
    debouncer.run(() => calls.add(3));

    await tester.pump(const Duration(milliseconds: 80));
    expect(calls, [3]);
  });

  testWidgets('cancel prevents a pending action from running', (tester) async {
    final debouncer = Debouncer(duration: const Duration(milliseconds: 50));
    addTearDown(debouncer.dispose);

    var ran = false;
    debouncer.run(() => ran = true);
    debouncer.cancel();

    await tester.pump(const Duration(milliseconds: 80));
    expect(ran, isFalse);
  });

  testWidgets('a new window starts after the previous one fires', (
    tester,
  ) async {
    final debouncer = Debouncer(duration: const Duration(milliseconds: 50));
    addTearDown(debouncer.dispose);

    final calls = <int>[];
    debouncer.run(() => calls.add(1));
    await tester.pump(const Duration(milliseconds: 80));
    debouncer.run(() => calls.add(2));
    await tester.pump(const Duration(milliseconds: 80));

    expect(calls, [1, 2]);
  });
}
