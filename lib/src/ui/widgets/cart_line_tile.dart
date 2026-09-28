import 'package:flutter/material.dart';

import '../../util/currency.dart';
import 'image_thumb.dart';
import 'money_text.dart';
import 'qty_stepper.dart';

/// A single cart line: photo, name, chosen options, quantity and line
/// total, with a per-line savings note.
///
/// The quantity control is a [QtyStepper] when [onQuantityChanged] is
/// given, and a plain "×N" label otherwise (e.g. a read-only receipt
/// preview) — this widget holds no quantity state of its own either way,
/// matching [QtyStepper]'s own contract.
class CartLineTile extends StatelessWidget {
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

  final String name;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final String? optionsSummary;
  final double? savingsAmount;
  final String? savingsLabel;
  final String? imageUrl;
  final int freeQty;
  final ValueChanged<int>? onQuantityChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImageThumb(
              url: imageUrl,
              width: _thumbSize,
              height: _thumbSize,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: theme.textTheme.bodyLarge),
                  if (optionsSummary != null)
                    Text(
                      optionsSummary!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      MoneyText(
                        unitPrice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        ' × $quantity',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (freeQty > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '+$freeQty gratis',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (savingsAmount != null && savingsAmount! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${savingsLabel ?? 'Hemat'} ${Money.format(savingsAmount!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                    tooltip: 'Hapus',
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(height: 4),
                MoneyText(
                  lineTotal,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (onQuantityChanged != null)
                  QtyStepper(
                    value: quantity,
                    onChanged: onQuantityChanged!,
                    compact: true,
                    min: 0,
                  )
                else
                  Text('×$quantity', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
