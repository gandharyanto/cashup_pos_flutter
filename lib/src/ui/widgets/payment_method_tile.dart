/// A single selectable payment method row, used by the payment method
/// picker sheet.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A selectable payment method card: icon, name, optional subtitle.
///
/// Rendered muted and non-interactive when [enabled] is false — e.g. a
/// method temporarily disabled by merchant settings.
class PaymentMethodTile extends StatelessWidget {
  /// Creates a payment method tile.
  const PaymentMethodTile({
    super.key,
    required this.name,
    required this.code,
    this.subtitle,
    this.iconAsset,
    this.enabled = true,
    this.onTap,
  });

  /// The method's display name, e.g. `'QRIS'`.
  final String name;

  /// The backend's payment method code, used by the caller to track
  /// selection; not itself displayed.
  final String code;

  /// Optional secondary caption, e.g. a fee note.
  final String? subtitle;

  /// Optional asset path for the method's icon/logo. Falls back to a
  /// generic payment icon when null or when the asset fails to load.
  final String? iconAsset;

  /// Whether this method can currently be selected.
  final bool enabled;

  /// Called when the tile is tapped. Ignored when [enabled] is false.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Container(
            padding: EdgeInsets.all(_spacing.m),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: radius,
            ),
            child: Row(
              children: [
                _Icon(iconAsset: iconAsset),
                SizedBox(width: _spacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The method's logo, or a generic placeholder when unavailable.
class _Icon extends StatelessWidget {
  const _Icon({required this.iconAsset});

  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = iconAsset;
    const size = 32.0;

    Widget placeholder() => Icon(
      Icons.payments_outlined,
      size: 20,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: asset == null
          ? placeholder()
          : Image.asset(
              asset,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => placeholder(),
            ),
    );
  }
}
