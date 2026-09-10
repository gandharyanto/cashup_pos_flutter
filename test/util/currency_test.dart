import 'package:cashup_pos/src/util/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats rupiah with Indonesian grouping and no decimals', () {
    expect(Money.format(1250000), 'Rp 1.250.000');
    expect(Money.format(0), 'Rp 0');
    expect(Money.format(-2500), '-Rp 2.500');
  });

  test('omits the symbol when asked', () {
    expect(Money.format(1250000, withSymbol: false), '1.250.000');
  });

  test('rounds to whole rupiah by default', () {
    expect(Money.format(19860.5), 'Rp 19.861');
    expect(Money.format(19860.4), 'Rp 19.860');
  });

  test('keeps decimals when a scale is requested', () {
    expect(Money.format(1250.5, decimals: 2), 'Rp 1.250,50');
  });

  test('reuses one NumberFormat instance across calls', () {
    expect(identical(Money.debugFormatter, Money.debugFormatter), isTrue);
  });

  group('formatCompact', () {
    test('abbreviates millions and thousands for dense panels', () {
      expect(Money.formatCompact(1200000), 'Rp 1,2jt');
      expect(Money.formatCompact(18000), 'Rp 18rb');
    });

    test('rounds the abbreviated figure rather than truncating it', () {
      expect(Money.formatCompact(1250000), 'Rp 1,3jt');
      expect(Money.formatCompact(18600), 'Rp 19rb');
    });

    test('falls back to the full form below a thousand', () {
      expect(Money.formatCompact(750), 'Rp 750');
    });

    test('keeps the sign on negatives', () {
      expect(Money.formatCompact(-1250000), '-Rp 1,3jt');
    });
  });
}
