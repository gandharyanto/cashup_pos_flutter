import 'package:intl/intl.dart';

import 'num_utils.dart';

/// Rupiah formatting for the whole SDK.
///
/// Formatters are constructed once and reused. Building a [NumberFormat]
/// inside `build` is a measurable cost on a product grid, so every caller
/// comes through here rather than formatting locally.
///
/// Only number *symbols* are needed, which `intl` bundles statically for
/// every locale — no `initializeDateFormatting`-style setup is required of
/// the host app.
class Money {
  Money._();

  static final NumberFormat _grouped = NumberFormat.decimalPattern('id_ID');
  static final Map<int, NumberFormat> _withDecimals = {};

  /// Exposed only so a test can assert the instance is reused.
  static NumberFormat get debugFormatter => _grouped;

  /// Formats [amount] as `Rp 1.250.000`.
  ///
  /// Negative amounts render as `-Rp 2.500` — the sign leads the symbol,
  /// matching the receipt layout in the Kotlin original.
  static String format(
    double amount, {
    bool withSymbol = true,
    int decimals = 0,
  }) {
    final negative = amount < 0;
    final magnitude = amount.abs();
    final digits = decimals == 0
        ? _grouped.format(jvmRound(magnitude).toInt())
        : _decimalFormatter(decimals).format(magnitude);
    final body = withSymbol ? 'Rp $digits' : digits;
    return negative ? '-$body' : body;
  }

  /// Short form for dense tablet panels: `Rp 1,3jt`, `Rp 18rb`.
  ///
  /// Falls back to the full form below a thousand, where abbreviating would
  /// lose more precision than it saves width.
  static String formatCompact(double amount) {
    final magnitude = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (magnitude >= 1000000) {
      final millions = (magnitude / 1000000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return '${sign}Rp ${millions}jt';
    }
    if (magnitude >= 1000) {
      return '${sign}Rp ${(magnitude / 1000).toStringAsFixed(0)}rb';
    }
    return format(amount);
  }

  static NumberFormat _decimalFormatter(int decimals) =>
      _withDecimals.putIfAbsent(
        decimals,
        () => NumberFormat.decimalPatternDigits(
          locale: 'id_ID',
          decimalDigits: decimals,
        ),
      );
}
