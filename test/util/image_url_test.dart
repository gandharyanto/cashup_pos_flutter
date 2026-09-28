import 'package:cashup_pos/src/util/image_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joins a relative path onto the meta base url exactly once', () {
    expect(
      resolveImageUrl('/img/a.png', 'https://cdn.test/'),
      'https://cdn.test/img/a.png',
    );
    expect(
      resolveImageUrl('img/a.png', 'https://cdn.test'),
      'https://cdn.test/img/a.png',
    );
  });

  test('passes an absolute url through untouched', () {
    expect(
      resolveImageUrl('https://x.test/a.png', 'https://cdn.test/'),
      'https://x.test/a.png',
    );
  });

  test('returns null when either side is missing', () {
    expect(resolveImageUrl(null, 'https://cdn.test/'), isNull);
    expect(resolveImageUrl('/img/a.png', null), isNull);
  });
}
