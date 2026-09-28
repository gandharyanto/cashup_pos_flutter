import 'package:flutter/material.dart';

import 'money_text.dart';

/// Visual weight for an [AmountRow] — [AmountEmphasis.total] is the bold
/// grand-total row; [AmountEmphasis.muted] is a secondary breakdown line.
enum AmountEmphasis { normal, muted, strong, total }

/// One label/value row: a label (with an optional sublabel) on the left, a
/// [MoneyText] on the right.
///
/// Shared by cart totals, the receipt, transaction detail and the summary
/// report — the reason it lives in the shared widget library rather than
/// beside a single page.
class AmountRow extends StatelessWidget {
  const AmountRow({
    super.key,
    required this.label,
    required this.amount,
    this.sublabel,
    this.emphasis = AmountEmphasis.normal,
    this.negative = false,
  });

  final String label;
  final double amount;
  final String? sublabel;
  final AmountEmphasis emphasis;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = _textStyleFor(theme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: labelStyle),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          MoneyText(amount, style: labelStyle, negative: negative),
        ],
      ),
    );
  }

  TextStyle? _textStyleFor(ThemeData theme) {
    switch (emphasis) {
      case AmountEmphasis.muted:
        return theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
      case AmountEmphasis.total:
        return theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );
      case AmountEmphasis.strong:
        return theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );
      case AmountEmphasis.normal:
        return theme.textTheme.bodyMedium;
    }
  }
}
