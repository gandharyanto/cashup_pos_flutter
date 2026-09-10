import 'package:cashup_pos/src/calc/rounding_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyRounding', () {
    test('FLOOR rounds down to the target multiple', () {
      expect(
        RoundingUtils.applyRounding(amount: 10450, target: 100, type: 'FLOOR'),
        10400,
      );
    });

    test('CEILING rounds up to the target multiple', () {
      expect(
        RoundingUtils.applyRounding(
          amount: 10450,
          target: 100,
          type: 'CEILING',
        ),
        10500,
      );
    });

    test('ROUND picks the nearest multiple, halves going up', () {
      expect(
        RoundingUtils.applyRounding(amount: 10450, target: 100, type: 'ROUND'),
        10500,
      );
      expect(
        RoundingUtils.applyRounding(amount: 10440, target: 100, type: 'ROUND'),
        10400,
      );
    });

    test('NONE and a non-positive target leave the amount untouched', () {
      expect(
        RoundingUtils.applyRounding(amount: 10450, target: 100, type: 'NONE'),
        10450,
      );
      expect(
        RoundingUtils.applyRounding(amount: 10450, target: 0, type: 'CEILING'),
        10450,
      );
      expect(
        RoundingUtils.applyRounding(amount: 10450, target: -100, type: 'FLOOR'),
        10450,
      );
    });

    test('the type is matched case-insensitively', () {
      expect(
        RoundingUtils.applyRounding(
          amount: 10450,
          target: 100,
          type: 'ceiling',
        ),
        10500,
      );
    });

    test('an unknown type leaves the amount untouched', () {
      expect(
        RoundingUtils.applyRounding(amount: 10450, target: 100, type: 'WOBBLE'),
        10450,
      );
    });

    test('an amount already on the target is unchanged by any type', () {
      for (final type in const ['FLOOR', 'CEILING', 'ROUND']) {
        expect(
          RoundingUtils.applyRounding(amount: 10400, target: 100, type: type),
          10400,
          reason: type,
        );
      }
    });

    test('rounds to a thousand target as well as a hundred', () {
      expect(
        RoundingUtils.applyRounding(
          amount: 10450,
          target: 1000,
          type: 'CEILING',
        ),
        11000,
      );
      expect(
        RoundingUtils.applyRounding(amount: 10450, target: 1000, type: 'FLOOR'),
        10000,
      );
    });
  });

  group('calculateRoundingAdjustment', () {
    test('reports the signed delta', () {
      expect(RoundingUtils.calculateRoundingAdjustment(10450, 10500), 50);
      expect(RoundingUtils.calculateRoundingAdjustment(10450, 10400), -50);
      expect(RoundingUtils.calculateRoundingAdjustment(10400, 10400), 0);
    });
  });
}
