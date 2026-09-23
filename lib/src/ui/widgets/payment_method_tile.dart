import 'package:flutter/material.dart';

/// A single selectable payment method row (cash, QRIS, a card network, ...)
/// used by the checkout payment-method picker.
///
/// [code] is the backend's payment method code — not shown, but kept on the
/// widget so a caller building the row from a list doesn't need to carry it
/// separately alongside the tile.
class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.name,
    required this.code,
    this.subtitle,
    this.iconAsset,
    this.enabled = true,
    this.onTap,
  });

  final String name;
  final String code;
  final String? subtitle;
  final String? iconAsset;
  final bool enabled;
  final VoidCallback? onTap;

  static const double _cornerRadius = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledColor = theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(_cornerRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _leadingIcon(theme, disabledColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: enabled ? null : disabledColor,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: enabled
                              ? theme.colorScheme.onSurfaceVariant
                              : disabledColor,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: enabled
                    ? theme.colorScheme.onSurfaceVariant
                    : disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon(ThemeData theme, Color disabledColor) {
    if (iconAsset != null) {
      return SizedBox(
        width: 32,
        height: 32,
        child: Image.asset(
          iconAsset!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.payment, color: enabled ? null : disabledColor),
        ),
      );
    }
    return Icon(
      Icons.payment,
      color: enabled ? theme.colorScheme.primary : disabledColor,
    );
  }
}
