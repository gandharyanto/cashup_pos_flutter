import 'package:cashup_pos/src/ui/pages/manage_category_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category name is required', () {
    expect(validateCategoryName(null), 'Nama kategori wajib diisi');
    expect(validateCategoryName('   '), 'Nama kategori wajib diisi');
    expect(validateCategoryName('Minuman'), isNull);
  });
}
