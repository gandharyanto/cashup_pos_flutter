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
///
/// Money strings follow the same rule: `DecimalFormat("0.00")` and
/// `DecimalFormat("0.##")` round HALF_EVEN, which neither
/// [double.toStringAsFixed] nor intl's `NumberFormat` does. See
/// [jvmFormatFixed2] and [jvmFormatUpTo2].
library;

import 'dart:math' as math;

const int _charZero = 0x30;
const int _charFive = 0x35;
const int _charNine = 0x39;
const int _charDot = 0x2E;

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

/// `java.text.DecimalFormat("0.00", DecimalFormatSymbols(Locale.US))` on the
/// JDK: no grouping, `.` separator, exactly two decimals.
///
/// The Kotlin payload builds every money string this way, and the default
/// rounding mode is HALF_EVEN — so an exact binary tie goes to the even cent
/// (`12000.125` → `12000.12`), where `toStringAsFixed` and intl's
/// `NumberFormat` both round it up to `12000.13`. See [_jvmRoundToCents] for
/// how the JDK decides everything else.
String jvmFormatFixed2(double value) =>
    _jvmDecimalFormat(value, trimTrailingZeros: false);

/// `java.text.DecimalFormat("0.##", DecimalFormatSymbols(Locale.US))` on the
/// JDK: as [jvmFormatFixed2], then trailing zeros and a bare point dropped
/// (`1500.0` → `1500`, `1500.5` → `1500.5`).
String jvmFormatUpTo2(double value) =>
    _jvmDecimalFormat(value, trimTrailingZeros: true);

String _jvmDecimalFormat(double value, {required bool trimTrailingZeros}) {
  if (value.isNaN) return 'NaN';
  // isNegative is true for -0.0, and the JDK prints "-0.00" for it — and for
  // any small negative that rounds to zero.
  final sign = value.isNegative ? '-' : '';
  if (value.isInfinite) return '$sign∞';

  var text = _jvmRoundToCents(value.abs());
  if (trimTrailingZeros) {
    var end = text.length;
    while (text.codeUnitAt(end - 1) == _charZero) {
      end--;
    }
    if (text.codeUnitAt(end - 1) == _charDot) end--;
    text = text.substring(0, end);
  }
  return '$sign$text';
}

/// [magnitude] (non-negative, finite) rounded HALF_EVEN to two decimals, as
/// `I.FF`.
///
/// The JDK's `DigitList` rounds the *shortest* decimal representation — the
/// digits of `Double.toString`, which Dart's [double.toString] reproduces —
/// and consults the binary value only when the digit after the cut is a final
/// `5`, i.e. when the shortest form is itself a cent midpoint:
///
/// * the double *is* that midpoint (`x × 8` is an integer, so the fraction is
///   an odd multiple of 1/8) — a true tie, rounded to the even cent;
/// * otherwise the double sits just to one side of it (`1.115` is stored as
///   `1.11499999…`), and it rounds the way the exact value does — which is
///   what [double.toStringAsFixed] computes.
///
/// Every other case is decided by the shortest digits alone. For money
/// magnitudes that agrees with the exact value; it differs only where a
/// double is coarser than a cent (`1e15 + 0.125` → `…0.10`), and the JDK
/// behaviour is kept there too.
String _jvmRoundToCents(double magnitude) {
  final text = magnitude.toString();
  if (text.contains('e')) {
    // Exponential form: below 1e-6, which rounds to zero, or at 1e21 and
    // above, where every double is already an integer.
    return magnitude < 1 ? '0.00' : '${BigInt.from(magnitude)}.00';
  }

  final dot = text.indexOf('.');
  if (dot < 0) return '$text.00';
  final fractionLength = text.length - dot - 1;
  if (fractionLength <= 2) {
    return fractionLength == 2 ? text : '${text}0';
  }

  final kept = text.substring(0, dot + 3);
  final roundingDigit = text.codeUnitAt(dot + 3);

  if (roundingDigit == _charFive && fractionLength == 3) {
    if ((magnitude * 8) % 1 != 0) return magnitude.toStringAsFixed(2);
    final lastKeptIsOdd = text.codeUnitAt(dot + 2).isOdd;
    return lastKeptIsOdd ? _incrementCents(kept, dot) : kept;
  }

  // Past a 5 the shortest form always has a non-zero digit, so >= 5 is above
  // the midpoint.
  return roundingDigit >= _charFive ? _incrementCents(kept, dot) : kept;
}

/// Adds one cent to `I.FF`, carrying into the integer part.
String _incrementCents(String kept, int dot) {
  final digits = _incrementDigits(
    kept.substring(0, dot) + kept.substring(dot + 1),
  );
  final cut = digits.length - 2;
  return '${digits.substring(0, cut)}.${digits.substring(cut)}';
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
