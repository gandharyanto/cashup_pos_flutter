import 'package:cashup_pos/src/ui/widgets/image_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('decodes at display size via cacheWidth/cacheHeight', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ImageThumb(
            url: 'https://cdn.test/a.png',
            width: 80,
            height: 40,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    // Image.network with cacheWidth/cacheHeight composes its ImageProvider
    // into a ResizeImage carrying the decode target size — that is the
    // only place those constructor arguments are observable afterwards.
    // devicePixelRatio in the test harness is 1.0, so cache dimensions
    // match the logical size exactly.
    final provider = image.image as ResizeImage;
    expect(provider.width, 80);
    expect(provider.height, 40);
  });

  testWidgets('shows a placeholder icon when url is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ImageThumb(
            url: null,
            width: 40,
            height: 40,
            placeholderIcon: Icons.category_outlined,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
