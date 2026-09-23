import 'package:cashup_pos/src/ui/pages/manage_product_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product editor validates required name and non-negative price', () {
    expect(validateProductName('  '), 'Nama produk wajib diisi');
    expect(validateProductName('Kopi'), isNull);
    expect(validateProductPrice('abc'), 'Harga tidak valid');
    expect(validateProductPrice('-1'), 'Harga tidak valid');
    expect(validateProductPrice('0'), isNull);
    expect(validateProductPrice('15000'), isNull);
  });
}
