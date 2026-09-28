/// One label/value money row. Used by cart totals, the receipt, transaction
/// detail and the summary report — the reason it lives in the shared
/// widget library rather than beside a single page.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';
import 'money_text.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// Visual weight of an [AmountRow], from a muted secondary line up to a
/// bold grand-total line.
enum AmountEmphasis {
  /// Default body-text weight.
  normal,

  /// Smaller, secondary-coloured text — e.g. a per-item note.
  muted,

  /// Bold body text — e.g. a subtotal before the grand total.
  strong,

  /// The grand-total line: largest and boldest.
  total,
}

/// A single `label ... amount` row, formatted through [MoneyText].
class AmountRow extends StatelessWidget {
  /// Creates an amount row.
  const AmountRow({
    super.key,
    required this.label,
    required this.amount,
    this.sublabel,
    this.emphasis = AmountEmphasis.normal,
    this.negative = false,
  });

  /// The row's label, e.g. `'Subtotal'` or `'Diskon'`.
  final String label;

  /// The amount, as a magnitude (see [negative]).
  final double amount;

  /// Optional small caption under [label].
  final String? sublabel;

  /// Visual weight of this row.
  final AmountEmphasis emphasis;

  /// When true, the amount renders with a leading `-`.
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final TextStyle? textStyle = switch (emphasis) {
      AmountEmphasis.normal => theme.textTheme.bodyMedium,
      AmountEmphasis.muted => theme.textTheme.bodySmall?.copyWith(
        color: mutedColor,
      ),
      AmountEmphasis.strong => theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      AmountEmphasis.total => theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    };

    return Padding(
      padding: EdgeInsets.symmetric(vertical: _spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: textStyle),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                    ),
                  ),
              ],
            ),
          ),
          MoneyText(amount, negative: negative, style: textStyle),
        ],
      ),
    );
  }
}
