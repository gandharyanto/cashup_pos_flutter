import 'package:cashup_pos/src/ui/widgets/async_view.dart';
import 'package:cashup_pos/src/ui/widgets/empty_state.dart';
import 'package:cashup_pos/src/ui/widgets/error_state.dart';
import 'package:cashup_pos/src/ui/widgets/loading_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the loading state while pending', (tester) async {
    await tester.pumpWidget(
      wrap(
        AsyncView<List<int>>(
          value: const AsyncValue.loading(),
          data: (_) => const Text('data'),
        ),
      ),
    );
    expect(find.byType(LoadingState), findsOneWidget);
  });

  testWidgets('shows the error state with a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        AsyncView<List<int>>(
          value: AsyncValue.error(Exception('boom'), StackTrace.empty),
          onRetry: () => retried = true,
          data: (_) => const Text('data'),
        ),
      ),
    );
    expect(find.byType(ErrorState), findsOneWidget);
    await tester.tap(find.text('Coba Lagi'));
    expect(retried, isTrue);
  });

  testWidgets('shows the empty state when isEmpty reports true', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        AsyncView<List<int>>(
          value: const AsyncValue.data(<int>[]),
          isEmpty: (items) => items.isEmpty,
          empty: const EmptyState(title: 'Kosong'),
          data: (_) => const Text('data'),
        ),
      ),
    );
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('data'), findsNothing);
  });

  testWidgets('shows data when present and not empty', (tester) async {
    await tester.pumpWidget(
      wrap(
        AsyncView<List<int>>(
          value: const AsyncValue.data(<int>[1]),
          isEmpty: (items) => items.isEmpty,
          data: (_) => const Text('data'),
        ),
      ),
    );
    expect(find.text('data'), findsOneWidget);
  });
}
