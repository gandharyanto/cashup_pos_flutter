/// A single cart line row: image, name, chosen variant/modifier summary, a
/// quantity control and the line total. Used by the cart panel on phone
/// and tablet alike.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';
import '../../util/currency.dart';
import 'image_thumb.dart';
import 'money_text.dart';
import 'qty_stepper.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// One row of the cart.
///
/// [onRemove] fires when the quantity stepper is decremented past one
/// (i.e. to zero) — there is no separate delete affordance, matching the
/// reference cart, where removal is just stepping a line down to nothing.
class CartLineTile extends StatelessWidget {
  /// Creates a cart line tile.
  const CartLineTile({
    super.key,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.optionsSummary,
    this.savingsAmount,
    this.savingsLabel,
    this.imageUrl,
    this.freeQty = 0,
    this.onQuantityChanged,
    this.onRemove,
    this.onTap,
  });

  /// The product name.
  final String name;

  /// The unit price before any per-line promotion.
  final double unitPrice;

  /// The current quantity on this line.
  final int quantity;

  /// The line's total amount, already net of savings, shown right-aligned.
  final double lineTotal;

  /// A short summary of the chosen variant/modifier options, e.g.
  /// `'Besar, Less Sugar'`.
  final String? optionsSummary;

  /// Amount saved on this line by an applied promotion, if any.
  final double? savingsAmount;

  /// Overrides the default `'Hemat Rp ...'` savings badge text.
  final String? savingsLabel;

  /// The line's product image url, already resolved.
  final String? imageUrl;

  /// Quantity on this line that is free (buy-x-get-y style promotions).
  final int freeQty;

  /// Called with the new quantity when the stepper changes it above zero.
  final ValueChanged<int>? onQuantityChanged;

  /// Called when the stepper is decremented to zero.
  final VoidCallback? onRemove;

  /// Called when the row itself is tapped, e.g. to edit options or add a
  /// note.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSavings = (savingsAmount ?? 0) > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _spacing.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImageThumb(
              url: imageUrl,
              width: 56,
              height: 56,
              placeholderIcon: Icons.fastfood_outlined,
            ),
            SizedBox(width: _spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (optionsSummary != null)
                    Text(
                      optionsSummary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (freeQty > 0)
                    Text(
                      '$freeQty gratis',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (hasSavings)
                    Padding(
                      padding: EdgeInsets.only(top: _spacing.xs),
                      child: _SavingsBadge(
                        savingsLabel ?? 'Hemat ${Money.format(savingsAmount!)}',
                      ),
                    ),
                  SizedBox(height: _spacing.s),
                  QtyStepper(
                    value: quantity,
                    compact: true,
                    onChanged: (next) {
                      if (next <= 0) {
                        onRemove?.call();
                      } else {
                        onQuantityChanged?.call(next);
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: _spacing.m),
            MoneyText(
              lineTotal,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small pill badge showing the amount saved on a cart line.
class _SavingsBadge extends StatelessWidget {
  const _SavingsBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _spacing.s, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
