import 'package:cashup_pos/src/util/num_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('jvmRound', () {
    test('rounds halves toward positive infinity like java.lang.Math.round', () {
      expect(jvmRound(2.5), 3.0);
      expect(jvmRound(2.4), 2.0);
      // The divergence that motivates this helper: Dart's num.round() gives -3.
      expect(jvmRound(-2.5), -2.0);
      expect((-2.5).round(), -3);
    });

    test('leaves whole numbers alone', () {
      expect(jvmRound(0), 0.0);
      expect(jvmRound(121062), 121062.0);
      expect(jvmRound(-7), -7.0);
    });

    test('matches the server on the discount case that motivated it', () {
      // 121062 x 25% = 30265.5; the server rounds to 30266.
      expect(jvmRound(121062 * 25 / 100.0), 30266.0);
    });
  });

  group('setScale', () {
    test('rounds half up on the absolute value', () {
      expect(setScale(1.005, 2), 1.01);
      expect(setScale(2.344, 2), 2.34);
      expect(setScale(-1.005, 2), -1.01);
    });

    test('leaves a value alone when it already fits the scale', () {
      expect(setScale(1.5, 2), 1.5);
      expect(setScale(1800, 2), 1800.0);
      expect(setScale(0, 2), 0.0);
    });

    test(
      'matches BigDecimal.valueOf(double).setScale on binary-inexact input',
      () {
        // 1.005 is stored as 1.00499999999999989..., so a naive multiply-and-floor
        // yields 1.00. BigDecimal.valueOf uses the shortest decimal representation
        // and yields 1.01, which is what the backend computes.
        expect(setScale(1.005, 2), isNot(1.00));
        expect(setScale(8.835, 2), 8.84);
        expect(setScale(0.615, 2), 0.62);
      },
    );

    test('supports the scale-10 intermediate used by the tax computation', () {
      expect(setScale(0.11, 10), 0.11);
      expect(setScale(1980.0000000001, 10), 1980.0000000001);
    });
  });

  group('roundToIntegerForCash', () {
    test('rounds up from a half rupiah, down below it', () {
      expect(roundToIntegerForCash(1805.5), 1806.0);
      expect(roundToIntegerForCash(1805.49), 1805.0);
    });

    test('leaves whole rupiah untouched', () {
      expect(roundToIntegerForCash(19860), 19860.0);
    });
  });

  // Every expected string below was produced by a real JVM run of
  // java.text.DecimalFormat("0.00" / "0.##", DecimalFormatSymbols(Locale.US))
  // on OpenJDK 25 (the Android Studio JBR), not derived by hand.
  group('jvmFormatFixed2', () {
    test('rounds an exact binary tie to the even cent', () {
      expect(jvmFormatFixed2(12000.125), '12000.12');
      expect(jvmFormatFixed2(12000.375), '12000.38');
      expect(jvmFormatFixed2(12000.625), '12000.62');
      expect(jvmFormatFixed2(12000.875), '12000.88');
      expect(jvmFormatFixed2(0.125), '0.12');
      expect(jvmFormatFixed2(0.375), '0.38');
      expect(jvmFormatFixed2(0.625), '0.62');
      expect(jvmFormatFixed2(0.875), '0.88');
      expect(jvmFormatFixed2(1.125), '1.12');
      expect(jvmFormatFixed2(2.375), '2.38');
    });

    test('keeps the even-cent rounding at large rupiah magnitudes', () {
      expect(jvmFormatFixed2(123456789.125), '123456789.12');
      expect(jvmFormatFixed2(123456789.375), '123456789.38');
      expect(jvmFormatFixed2(987654321.625), '987654321.62');
    });

    test(
      'rounds a near-tie by the exact binary value, not its decimal look',
      () {
        // 1.115 is stored as 1.11499999…, 0.005 as 0.00500000000000000010….
        // These are the values intl's NumberFormat got wrong.
        expect(jvmFormatFixed2(0.745), '0.74');
        expect(jvmFormatFixed2(1.115), '1.11');
        expect(jvmFormatFixed2(1.855), '1.85');
        expect(jvmFormatFixed2(1.005), '1.00');
        expect(jvmFormatFixed2(2.675), '2.67');
        expect(jvmFormatFixed2(0.005), '0.01');
        expect(jvmFormatFixed2(0.015), '0.01');
      },
    );

    test('rounds negative ties symmetrically', () {
      expect(jvmFormatFixed2(-12000.125), '-12000.12');
      expect(jvmFormatFixed2(-12000.375), '-12000.38');
      expect(jvmFormatFixed2(-0.625), '-0.62');
      expect(jvmFormatFixed2(-0.875), '-0.88');
      expect(jvmFormatFixed2(-0.005), '-0.01');
    });

    test('keeps the minus sign on negative zero and on negatives that round to zero', () {
      expect(jvmFormatFixed2(-0.0), '-0.00');
      expect(jvmFormatFixed2(-0.001), '-0.00');
      expect(jvmFormatFixed2(-0.004), '-0.00');
      expect(jvmFormatFixed2(0.0), '0.00');
      expect(jvmFormatFixed2(0.001), '0.00');
    });

    test('pads to two places and carries through nines', () {
      expect(jvmFormatFixed2(1500.0), '1500.00');
      expect(jvmFormatFixed2(1500.5), '1500.50');
      expect(jvmFormatFixed2(-1500.5), '-1500.50');
      expect(jvmFormatFixed2(0.1 + 0.2), '0.30');
      expect(jvmFormatFixed2(9.999), '10.00');
      expect(jvmFormatFixed2(19714.285714285714), '19714.29');
      expect(jvmFormatFixed2(1971.4285714285713), '1971.43');
    });

    test('follows the shortest representation beyond cent precision', () {
      // At 1e15 a double's step is 0.125; the JDK formats the shortest
      // decimal "1000000000000000.1", not the exact tie.
      expect(jvmFormatFixed2(1e15 + 0.125), '1000000000000000.10');
    });

    test('formats non-finite values with the US symbols', () {
      expect(jvmFormatFixed2(double.nan), 'NaN');
      expect(jvmFormatFixed2(double.infinity), '∞');
      expect(jvmFormatFixed2(double.negativeInfinity), '-∞');
    });
  });

  group('jvmFormatUpTo2', () {
    test('drops trailing zeros and a bare point', () {
      expect(jvmFormatUpTo2(1500.0), '1500');
      expect(jvmFormatUpTo2(1500.5), '1500.5');
      expect(jvmFormatUpTo2(1500.05), '1500.05');
      expect(jvmFormatUpTo2(1500.10), '1500.1');
      expect(jvmFormatUpTo2(-1500.5), '-1500.5');
      expect(jvmFormatUpTo2(0.1 + 0.2), '0.3');
    });

    test('rounds with the same HALF_EVEN rule as 0.00', () {
      expect(jvmFormatUpTo2(0.125), '0.12');
      expect(jvmFormatUpTo2(12000.875), '12000.88');
      expect(jvmFormatUpTo2(1.005), '1');
      expect(jvmFormatUpTo2(1.115), '1.11');
      expect(jvmFormatUpTo2(0.005), '0.01');
    });

    test('keeps the minus sign on negative zero', () {
      expect(jvmFormatUpTo2(-0.0), '-0');
      expect(jvmFormatUpTo2(-0.004), '-0');
      expect(jvmFormatUpTo2(0.001), '0');
    });
  });

  group('atLeastZero', () {
    test('clamps negatives to zero and passes the rest through', () {
      expect(atLeastZero(-1), 0.0);
      expect(atLeastZero(0), 0.0);
      expect(atLeastZero(12.5), 12.5);
    });
  });

  group('json coercion', () {
    test('accepts the numeric strings the backend sends', () {
      expect(asDouble('12500.00'), 12500.0);
      expect(asInt('3'), 3);
      expect(asBool('true'), isTrue);
      expect(asIntList(['1', 2]), [1, 2]);
    });

    test('passes through native json types', () {
      expect(asDouble(12500), 12500.0);
      expect(asInt(3.0), 3);
      expect(asBool(1), isTrue);
      expect(asBool(0), isFalse);
    });

    test('returns null rather than throwing on unusable input', () {
      expect(asDouble(null), isNull);
      expect(asDouble('abc'), isNull);
      expect(asInt('abc'), isNull);
      expect(asBool('maybe'), isNull);
      expect(asIntList(null), isEmpty);
      expect(asIntList('not a list'), isEmpty);
    });

    test('drops unparsable entries from an id list rather than failing', () {
      expect(asIntList([1, 'x', 3]), [1, 3]);
    });
  });
}
