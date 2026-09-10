/// Numeric helpers that reproduce the JVM rounding semantics used by the
/// original Kotlin POS calculator.
///
/// The Kotlin implementation mixes three rounding styles and the backend
/// validates against them, so each one has an explicit counterpart here:
///
/// * `Math.round(x)` / `roundToInt()` — half-up, ties toward positive
///   infinity. Dart's [num.round] rounds ties *away from zero*, which differs
///   for negative values, so [jvmRound] is used instead.
/// * `BigDecimal.setScale(n, HALF_UP)` — half-up on the absolute value.
///   See [setScale].
/// * `floor` / `ceil` — identical in both languages.
///
/// The original uses [BigDecimal] only inside the tax computation. This port
/// keeps `double` arithmetic and applies [setScale] at the same points; for
/// money-magnitude inputs the results are identical.
library;

import 'dart:math' as math;

/// Half-up rounding with ties going toward positive infinity, matching
/// `java.lang.Math.round` and Kotlin's `roundToInt()` / `roundToLong()`.
double jvmRound(double value) => (value + 0.5).floorToDouble();

/// Rounds [value] to [scale] decimal places using HALF_UP on the absolute
/// value, matching `BigDecimal.setScale(scale, RoundingMode.HALF_UP)`.
double setScale(double value, int scale) {
  if (value.isNaN || value.isInfinite) return value;
  final factor = math.pow(10, scale).toDouble();
  final scaled = (value.abs() * factor) + 0.5;
  final result = scaled.floorToDouble() / factor;
  return value.isNegative ? -result : result;
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
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt();
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
List<int> asIntList(Object? value) {
  if (value is! List) return const [];
  return value.map(asInt).whereType<int>().toList(growable: false);
}
