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
}
