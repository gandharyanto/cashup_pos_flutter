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
/// Money strings mirror Android rather than desktop JDK: its ICU-backed
/// `DecimalFormat("0.00")` / `DecimalFormat("0.##")` round HALF_EVEN on the
/// shortest decimal digits, which neither [double.toStringAsFixed] nor
/// intl's `NumberFormat` does. See [formatDecimalFixed2] and
/// [formatDecimalUpTo2].
library;

import 'dart:math' as math;

const int _charZero = 0x30;
const int _charOne = 0x31;
const int _charFive = 0x35;
const int _charNine = 0x39;
const int _charDot = 0x2E;
const int _charMinus = 0x2D;
const int _charPlus = 0x2B;

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

/// Formats [value] the way Android's
/// `java.text.DecimalFormat("0.00", DecimalFormatSymbols(Locale.US))` does:
/// no grouping, `.` separator, exactly two decimals.
///
/// On Android that class is backed by ICU, which rounds HALF_EVEN on the
/// *shortest round-trip decimal* of the double — the digits of
/// [double.toString] — and never looks at the binary value. Desktop JDK
/// consults the binary value when those digits are a midpoint, so the two
/// disagree on near-ties: `1.115` (stored as `1.11499999…`) is `"1.12"` here
/// and on Android, `"1.11"` on JDK. Exact binary ties agree on both:
/// `12000.125` → `"12000.12"`.
///
/// The payload targets Android because that is what the backend has been
/// accepting from shipping clients. [double.toStringAsFixed] and intl's
/// `NumberFormat` match neither: both round `12000.125` up to `"12000.13"`.
String formatDecimalFixed2(double value) =>
    _formatDecimal2(value, trimTrailingZeros: false);

/// As [formatDecimalFixed2], for Android's
/// `java.text.DecimalFormat("0.##", DecimalFormatSymbols(Locale.US))`:
/// trailing zeros and a bare point are dropped (`1500.0` → `"1500"`,
/// `1500.5` → `"1500.5"`).
///
/// It differs from desktop JDK the same way: `1.115` → `"1.12"` here,
/// `"1.11"` on JDK.
String formatDecimalUpTo2(double value) =>
    _formatDecimal2(value, trimTrailingZeros: true);

/// HALF_EVEN to two decimals, done on the decimal digits of the shortest
/// representation rather than with binary arithmetic.
String _formatDecimal2(double value, {required bool trimTrailingZeros}) {
  if (value.isNaN) return 'NaN';
  // isNegative is true for -0.0. ICU prints "-0.00" for it, and for any
  // small negative that rounds to zero.
  final negative = value.isNegative;
  if (value.isInfinite) return negative ? '-∞' : '∞';

  // "12000.125", "1500.0", "1e-7", "1.2345e+22".
  final text = value.abs().toString();
  final exponentAt = text.indexOf('e');
  final mantissaEnd = exponentAt < 0 ? text.length : exponentAt;

  // The mantissa's digits as code units, with a spare slot in front for a
  // carry out of the leading digit. The value is 0.DIGITS × 10^decimalAt.
  final digits = List<int>.filled(mantissaEnd + 1, _charZero);
  var end = 1;
  var decimalAt = -1;
  for (var i = 0; i < mantissaEnd; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == _charDot) {
      decimalAt = end - 1;
    } else {
      digits[end++] = unit;
    }
  }
  if (decimalAt < 0) decimalAt = end - 1;
  if (exponentAt >= 0) decimalAt += _exponentOf(text, exponentAt + 1);

  // Narrow to the significant digits, [start, end).
  var start = 1;
  while (start < end && digits[start] == _charZero) {
    start++;
    decimalAt--;
  }
  while (end > start && digits[end - 1] == _charZero) {
    end--;
  }

  final keep = decimalAt + 2; // significant digits left of the cut
  if (keep < 0) {
    // Every digit sits past the third decimal, so the value is below 0.001.
    end = start;
  } else if (start + keep < end) {
    final cut = start + keep;
    final roundingDigit = digits[cut];
    final bool roundUp;
    if (roundingDigit != _charFive) {
      roundUp = roundingDigit > _charFive;
    } else if (cut + 1 < end) {
      // Trailing zeros were trimmed, so a non-zero digit follows the 5.
      roundUp = true;
    } else {
      // The digits are exactly a midpoint: round to the even cent.
      roundUp = keep > 0 && digits[cut - 1].isOdd;
    }
    end = cut;
    if (roundUp) {
      var i = end - 1;
      while (i >= start && digits[i] == _charNine) {
        digits[i] = _charZero;
        i--;
      }
      if (i >= start) {
        digits[i]++;
      } else {
        start--;
        digits[start] = _charOne;
        decimalAt++;
      }
    }
  }

  final count = end - start;
  final out = StringBuffer();
  if (negative) out.writeCharCode(_charMinus);
  if (decimalAt <= 0) {
    out.writeCharCode(_charZero);
  } else {
    for (var i = 0; i < decimalAt; i++) {
      out.writeCharCode(i < count ? digits[start + i] : _charZero);
    }
  }
  final tenthsAt = decimalAt;
  final tenths = tenthsAt >= 0 && tenthsAt < count
      ? digits[start + tenthsAt]
      : _charZero;
  final hundredthsAt = decimalAt + 1;
  final hundredths = hundredthsAt >= 0 && hundredthsAt < count
      ? digits[start + hundredthsAt]
      : _charZero;
  if (!trimTrailingZeros || hundredths != _charZero) {
    out
      ..writeCharCode(_charDot)
      ..writeCharCode(tenths)
      ..writeCharCode(hundredths);
  } else if (tenths != _charZero) {
    out
      ..writeCharCode(_charDot)
      ..writeCharCode(tenths);
  }
  return out.toString();
}

/// Reads the signed exponent that starts at [index] in [text] (`-7`, `+22`)
/// without allocating a substring.
int _exponentOf(String text, int index) {
  var i = index;
  var sign = 1;
  final first = text.codeUnitAt(i);
  if (first == _charMinus) {
    sign = -1;
    i++;
  } else if (first == _charPlus) {
    i++;
  }
  var exponent = 0;
  for (; i < text.length; i++) {
    exponent = exponent * 10 + (text.codeUnitAt(i) - _charZero);
  }
  return sign * exponent;
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
