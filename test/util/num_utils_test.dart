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

  // Every expected string below was produced by ICU4J 75.1's DecimalFormat
  // ("0.00" / "0.##", DecimalFormatSymbols(Locale.US), HALF_EVEN) — the
  // implementation behind Android's java.text.DecimalFormat — not derived by
  // hand. Where desktop JDK prints something else, the comment says so.
  group('formatDecimalFixed2', () {
    test('rounds an exact binary tie to the even cent', () {
      expect(formatDecimalFixed2(12000.125), '12000.12');
      expect(formatDecimalFixed2(12000.375), '12000.38');
      expect(formatDecimalFixed2(12000.625), '12000.62');
      expect(formatDecimalFixed2(12000.875), '12000.88');
      expect(formatDecimalFixed2(0.125), '0.12');
      expect(formatDecimalFixed2(0.375), '0.38');
      expect(formatDecimalFixed2(0.625), '0.62');
      expect(formatDecimalFixed2(0.875), '0.88');
      expect(formatDecimalFixed2(1.125), '1.12');
      expect(formatDecimalFixed2(2.375), '2.38');
    });

    test('keeps the even-cent rounding at large rupiah magnitudes', () {
      expect(formatDecimalFixed2(123456789.125), '123456789.12');
      expect(formatDecimalFixed2(123456789.375), '123456789.38');
      expect(formatDecimalFixed2(987654321.625), '987654321.62');
    });

    test(
      'rounds a near-tie on its shortest decimal digits, not its binary value',
      () {
        // 1.115 is stored as 1.11499999…, but its shortest form "1.115" is a
        // midpoint, so HALF_EVEN goes to the even cent. Desktop JDK follows the
        // binary value instead: 1.11, 1.85, 2.67, 0.01, 0.01, 9.99.
        expect(formatDecimalFixed2(1.115), '1.12');
        expect(formatDecimalFixed2(1.855), '1.86');
        expect(formatDecimalFixed2(2.675), '2.68');
        expect(formatDecimalFixed2(0.015), '0.02');
        expect(formatDecimalFixed2(0.005), '0.00');
        expect(formatDecimalFixed2(9.995), '10.00');
        // Near-ties where the even cent is below — same on both runtimes.
        expect(formatDecimalFixed2(0.745), '0.74');
        expect(formatDecimalFixed2(1.005), '1.00');
      },
    );

    test(
      'rounds percentage shares at rupiah magnitudes the way Android does',
      () {
        // Desktop JDK: 990.05, 450.07, 990.27, 1350.53, 1350.67.
        expect(formatDecimalFixed2(18001 * 5.5 / 100), '990.06');
        expect(formatDecimalFixed2(18003 * 2.5 / 100), '450.08');
        expect(formatDecimalFixed2(18005 * 5.5 / 100), '990.28');
        expect(formatDecimalFixed2(18007 * 7.5 / 100), '1350.52');
        expect(formatDecimalFixed2(18009 * 7.5 / 100), '1350.68');
        expect(formatDecimalFixed2(18055 * 5.5 / 100), '993.02');
        expect(formatDecimalFixed2((10000 + 1100.5) * 5 / 100), '555.02');
      },
    );

    test('rounds negative ties and near-ties symmetrically', () {
      expect(formatDecimalFixed2(-12000.125), '-12000.12');
      expect(formatDecimalFixed2(-12000.375), '-12000.38');
      expect(formatDecimalFixed2(-0.625), '-0.62');
      expect(formatDecimalFixed2(-0.875), '-0.88');
      expect(formatDecimalFixed2(-1.115), '-1.12');
      expect(formatDecimalFixed2(-0.015), '-0.02');
    });

    test('keeps the minus sign on negative zero and on negatives that round to zero', () {
      expect(formatDecimalFixed2(-0.0), '-0.00');
      expect(formatDecimalFixed2(-0.001), '-0.00');
      expect(formatDecimalFixed2(-0.004), '-0.00');
      expect(formatDecimalFixed2(-0.005), '-0.00');
      expect(formatDecimalFixed2(0.0), '0.00');
      expect(formatDecimalFixed2(0.001), '0.00');
    });

    test('pads to two places and carries through nines', () {
      expect(formatDecimalFixed2(1500.0), '1500.00');
      expect(formatDecimalFixed2(1500.5), '1500.50');
      expect(formatDecimalFixed2(-1500.5), '-1500.50');
      expect(formatDecimalFixed2(0.1 + 0.2), '0.30');
      expect(formatDecimalFixed2(9.999), '10.00');
      expect(formatDecimalFixed2(0.995), '1.00');
      expect(formatDecimalFixed2(999999.995), '1000000.00');
      expect(formatDecimalFixed2(19714.285714285714), '19714.29');
      expect(formatDecimalFixed2(1971.4285714285713), '1971.43');
    });

    test('reads exponent forms of the shortest representation', () {
      expect(formatDecimalFixed2(1e-7), '0.00');
      expect(formatDecimalFixed2(5e-7), '0.00');
      expect(formatDecimalFixed2(double.minPositive), '0.00');
      expect(formatDecimalFixed2(1e21), '1000000000000000000000.00');
      expect(formatDecimalFixed2(1.2345e22), '12345000000000000000000.00');
      // A double this large is coarser than a cent; the shortest decimal is
      // "1000000000000000.1".
      expect(formatDecimalFixed2(1e15 + 0.125), '1000000000000000.10');
    });

    test('formats non-finite values with the US symbols', () {
      expect(formatDecimalFixed2(double.nan), 'NaN');
      expect(formatDecimalFixed2(double.infinity), '∞');
      expect(formatDecimalFixed2(double.negativeInfinity), '-∞');
    });
  });

  group('formatDecimalUpTo2', () {
    test('drops trailing zeros and a bare point', () {
      expect(formatDecimalUpTo2(1500.0), '1500');
      expect(formatDecimalUpTo2(1500.5), '1500.5');
      expect(formatDecimalUpTo2(1500.05), '1500.05');
      expect(formatDecimalUpTo2(1500.10), '1500.1');
      expect(formatDecimalUpTo2(-1500.5), '-1500.5');
      expect(formatDecimalUpTo2(0.1 + 0.2), '0.3');
      expect(formatDecimalUpTo2(1e21), '1000000000000000000000');
    });

    test('rounds with the same HALF_EVEN rule as 0.00', () {
      expect(formatDecimalUpTo2(0.125), '0.12');
      expect(formatDecimalUpTo2(12000.875), '12000.88');
      expect(formatDecimalUpTo2(1.005), '1');
      expect(formatDecimalUpTo2(1.115), '1.12');
      expect(formatDecimalUpTo2(0.005), '0');
      expect(formatDecimalUpTo2(9.995), '10');
    });

    test('keeps the minus sign on negative zero', () {
      expect(formatDecimalUpTo2(-0.0), '-0');
      expect(formatDecimalUpTo2(-0.004), '-0');
      expect(formatDecimalUpTo2(0.001), '0');
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
