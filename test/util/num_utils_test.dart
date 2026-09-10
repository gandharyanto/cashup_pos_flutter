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
