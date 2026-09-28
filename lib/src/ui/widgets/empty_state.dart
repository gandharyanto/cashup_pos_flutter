/// A centered "nothing here" placeholder, shown by [AsyncView] when a
/// collection value is present but empty.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

/// A full-space empty-collection placeholder.
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.action,
  });

  /// The headline, e.g. `'Belum ada transaksi'`.
  final String title;

  /// Optional supporting copy below [title].
  final String? message;

  /// Optional icon shown above [title].
  final IconData? icon;

  /// Optional call to action (e.g. a "coba muat ulang" button).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_spacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
              SizedBox(height: _spacing.m),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              SizedBox(height: _spacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[SizedBox(height: _spacing.l), action!],
          ],
        ),
      ),
    );
  }
}
