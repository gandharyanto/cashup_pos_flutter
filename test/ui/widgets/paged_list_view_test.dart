import 'package:cashup_pos/src/ui/widgets/paged_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('requests the next page when scrolled near the end', (
    tester,
  ) async {
    var loadMoreCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedListView<int>(
            items: List.generate(30, (i) => i),
            itemExtent: 60,
            hasMore: true,
            onLoadMore: () => loadMoreCalls++,
            itemBuilder: (context, item, index) =>
                SizedBox(height: 60, child: Text('row $item')),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pump();
    expect(loadMoreCalls, greaterThan(0));
  });

  testWidgets('shows the error footer with retry instead of loading', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedListView<int>(
            items: const [1, 2],
            hasMore: true,
            error: 'Gagal memuat',
            onRetry: () => retried = true,
            onLoadMore: () {},
            itemBuilder: (context, item, index) => Text('row $item'),
          ),
        ),
      ),
    );

    expect(find.text('Gagal memuat'), findsOneWidget);
    await tester.tap(find.text('Coba Lagi'));
    expect(retried, isTrue);
  });
}
