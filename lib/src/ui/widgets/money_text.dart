/// A single line of rupiah-formatted text, the shared entry point every
/// widget that displays a money amount goes through instead of formatting
/// locally.
library;

import 'package:flutter/material.dart';

import '../../util/currency.dart';

/// Renders [amount] as rupiah text.
///
/// [amount] is treated as a magnitude — [negative] decides the sign shown,
/// so callers never need to pre-negate their value.
class MoneyText extends StatelessWidget {
  /// Creates a money text.
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.compact = false,
    this.withSymbol = true,
    this.negative = false,
  });

  /// The amount to display, as a magnitude (see [negative]).
  final double amount;

  /// Text style override.
  final TextStyle? style;

  /// Uses [Money.formatCompact] (e.g. `'Rp 1,3jt'`) instead of
  /// [Money.format].
  final bool compact;

  /// Whether the `Rp` symbol is included. Ignored when [compact] is true —
  /// the compact form always carries the symbol.
  final bool withSymbol;

  /// When true, renders [amount] with a leading `-`.
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final signed = negative ? -amount.abs() : amount.abs();
    final text = compact
        ? Money.formatCompact(signed)
        : Money.format(signed, withSymbol: withSymbol);
    return Text(text, style: style);
  }
}
