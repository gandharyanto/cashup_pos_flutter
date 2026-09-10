/// Numeric helpers that reproduce the JVM rounding semantics used by the
/// original Kotlin POS calculator.
///
/// The Kotlin implementation mixes three rounding styles and the backend
/// validates against them, so each one has an explicit counterpart here:
///
/// * `Math.round(x)` / `roundToInt()` — half-up, ties toward positive
///   infinity. Dart's [num.round] rounds ties *away from zero*, which differs
///   for negative values, so [jvmRound] is used instead.
/// * `BigDecimal.setScale(n, HALF_UP)` — half-up on the decimal value.
///   See [setScale].
/// * `floor` / `ceil` — identical in both languages.
library;

import 'dart:math' as math;

const int _charZero = 0x30;
const int _charFive = 0x35;
const int _charNine = 0x39;

/// Half-up rounding with ties going toward positive infinity, matching
/// `java.lang.Math.round` and Kotlin's `roundToInt()` / `roundToLong()`.
double jvmRound(double value) => (value + 0.5).floorToDouble();

/// Rounds [value] to [scale] decimal places, matching
/// `BigDecimal.valueOf(value).setScale(scale, RoundingMode.HALF_UP)`.
///
/// The naive `(value * 10^scale + 0.5).floor() / 10^scale` is **not**
/// equivalent and diverges on ordinary money values. `setScale(1.005, 2)`
/// must be `1.01`: `BigDecimal.valueOf` builds its decimal from
/// `Double.toString`, which yields the shortest representation `"1.005"`,
/// so the half rounds up. The binary value is `1.00499999999999989…`, so
/// arithmetic scaling rounds it *down* to `1.00` instead — a one-cent gap
/// that the backend's tax validation rejects.
///
/// This implementation therefore rounds on the shortest decimal
/// representation, which is exactly what `BigDecimal.valueOf` does. Dart's
/// [double.toString] has the same shortest-round-trip contract as Java's
/// `Double.toString`.
double setScale(double value, int scale) {
  if (value.isNaN || value.isInfinite) return value;
  if (value == 0) return 0;

  final text = value.toString();
  // Very large or very small magnitudes render in exponential form. Money
  // values never reach that range; fall back to arithmetic scaling so the
  // function stays total.
  if (text.contains('e') || text.contains('E')) {
    return _setScaleBinary(value, scale);
  }

  final negative = text.startsWith('-');
  final magnitude = negative ? text.substring(1) : text;
  final dot = magnitude.indexOf('.');
  if (dot < 0) return value;

  final fraction = magnitude.substring(dot + 1);
  if (fraction.length <= scale) return value;

  final kept = magnitude.substring(0, dot) + fraction.substring(0, scale);
  final roundUp = fraction.codeUnitAt(scale) >= _charFive;
  final digits = roundUp ? _incrementDigits(kept) : kept;
  final rounded = _pointShiftedLeft(digits, scale);
  return negative ? -rounded : rounded;
}

double _setScaleBinary(double value, int scale) {
  final factor = math.pow(10, scale).toDouble();
  final scaled = (value.abs() * factor) + 0.5;
  final result = scaled.floorToDouble() / factor;
  return value.isNegative ? -result : result;
}

/// Adds one to a string of decimal digits, carrying as needed.
String _incrementDigits(String digits) {
  final units = digits.codeUnits.toList();
  for (var index = units.length - 1; index >= 0; index--) {
    if (units[index] == _charNine) {
      units[index] = _charZero;
    } else {
      units[index] = units[index] + 1;
      return String.fromCharCodes(units);
    }
  }
  return '1${String.fromCharCodes(units)}';
}

/// Reads [digits] as a decimal with the point [scale] places from the right.
///
/// The point is reinserted textually rather than dividing by a power of ten,
/// so the result is the nearest double to the intended decimal rather than
/// the nearest double to a quotient of two doubles.
double _pointShiftedLeft(String digits, int scale) {
  if (scale == 0) return double.parse(digits);
  final padded = digits.length <= scale
      ? digits.padLeft(scale + 1, '0')
      : digits;
  final cut = padded.length - scale;
  return double.parse('${padded.substring(0, cut)}.${padded.substring(cut)}');
}

/// Rounds to whole rupiah the way cash payments do: a fractional part of
/// 0.5 or more rounds up, anything less rounds down.
double roundToIntegerForCash(double amount) {
  final decimalPart = amount % 1.0;
  return decimalPart >= 0.5 ? amount.ceilToDouble() : amount.floorToDouble();
}

/// Clamps [value] to be at least zero.
double atLeastZero(double value) => value < 0 ? 0 : value;

/// Parses loosely-typed JSON numbers (backend sends both numbers and strings).
double? asDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', ''));
  return null;
}

/// Parses loosely-typed JSON integers.
int? asInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }
  return null;
}

/// Parses loosely-typed JSON booleans (backend sends `true`, `"true"` and `1`).
bool? asBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lowered = value.toLowerCase();
    if (lowered == 'true') return true;
    if (lowered == 'false') return false;
  }
  return null;
}

/// Parses a JSON list of ids that the backend may send as numbers or strings.
///
/// Unparsable entries are dropped rather than failing the whole list — a
/// malformed id in a promotion's target array must not break checkout.
List<int> asIntList(Object? value) {
  if (value is! List) return const [];
  return value.map(asInt).whereType<int>().toList(growable: false);
}
