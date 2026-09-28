import 'package:flutter/widgets.dart';

import '../../util/currency.dart';

/// Renders [amount] through [Money.format] / [Money.formatCompact] — the
/// only way an amount should reach the screen, so every page picks up
/// rupiah formatting (and any future locale change) for free.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.compact = false,
    this.withSymbol = true,
    this.negative = false,
  });

  final double amount;
  final TextStyle? style;

  /// Use [Money.formatCompact] (`Rp 1,3jt`) instead of the full grouped
  /// form. Ignores [withSymbol] — the compact form always carries the
  /// symbol.
  final bool compact;
  final bool withSymbol;

  /// Force a leading `-` regardless of [amount]'s own sign — used for rows
  /// that are conceptually a deduction (a discount, a refund) even though
  /// the underlying amount is stored as a positive magnitude.
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final signedAmount = negative ? -amount.abs() : amount;
    final text = compact
        ? Money.formatCompact(signedAmount)
        : Money.format(signedAmount, withSymbol: withSymbol);
    return Text(text, style: style);
  }
}
