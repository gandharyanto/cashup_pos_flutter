import 'package:flutter/material.dart';

/// A small coloured pill showing a transaction/payment status.
///
/// Recognises `PAID`, `PENDING`, `UNPAID` and `FAILED` (case-insensitive);
/// any other value is rendered as-is in a neutral colour rather than
/// throwing, since this reads directly off backend strings.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spec = switch (status.toUpperCase()) {
      'PAID' => _BadgeSpec(colorScheme.secondary, colorScheme.onSecondary),
      'PENDING' => _BadgeSpec(Colors.amber.shade700, Colors.white),
      'FAILED' => _BadgeSpec(colorScheme.error, colorScheme.onError),
      _ => _BadgeSpec(
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: spec.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BadgeSpec {
  const _BadgeSpec(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
