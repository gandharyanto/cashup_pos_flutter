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

  // Regression test for a `SliverFixedExtentList` overflow: an `itemExtent`
  // combined with a separator used to force the separator into the same
  // fixed-height slot as the row above it.
  testWidgets(
    'does not overflow when itemExtent is combined with a separator',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PagedListView<int>(
              items: List.generate(5, (i) => i),
              itemExtent: 40,
              hasMore: false,
              onLoadMore: () {},
              separator: const Divider(height: 8),
              itemBuilder: (context, item, index) =>
                  SizedBox(height: 40, child: Text('row $item')),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('row 0'), findsOneWidget);
    },
  );

  // Regression test for a `SliverFixedExtentList` overflow: an `itemExtent`
  // combined with the error/loading footer used to force the
  // naturally-taller footer into the same fixed-height slot as a row.
  testWidgets('does not overflow when itemExtent is combined with a footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedListView<int>(
            items: List.generate(5, (i) => i),
            itemExtent: 40,
            hasMore: true,
            error: 'Gagal memuat',
            onLoadMore: () {},
            itemBuilder: (context, item, index) =>
                SizedBox(height: 40, child: Text('row $item')),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Gagal memuat'), findsOneWidget);
  });
}
