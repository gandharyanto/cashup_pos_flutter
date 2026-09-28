/// A small colour-coded payment-status chip, used on transaction rows and
/// the transaction-detail header.
///
/// Colours are ported from the Kotlin tablet feature module's `colors.xml`
/// — a different, equally authoritative token set from the one
/// `PosTheme` is built from, and not present in `pos_design_tokens.xml`.
library;

import 'package:flutter/material.dart';

import '../../config/pos_theme.dart';

// `Color`'s wide-gamut fields aren't const-evaluable, so this is a
// module-level `final`, built once at load — not `const`, and never
// rebuilt inside `build`.
final _spacing = const PosTheme.cashup().spacing;

const Color _paidBg = Color(0xFFDCFCE7);
const Color _paidFg = Color(0xFF059669);
const Color _pendingBg = Color(0xFFFEF9C3);
const Color _pendingFg = Color(0xFFB45309);
const Color _unpaidBg = Color(0xFFFEE2E2);
const Color _unpaidFg = Color(0xFFDC2626);

/// A rounded-rect payment-status chip.
///
/// [status] is one of the backend's English status identifiers — `'PAID'`,
/// `'PENDING'`, `'UNPAID'`, `'FAILED'`; the Kotlin source token set has no
/// distinct colour for `'FAILED'`, so it reuses `'UNPAID'`'s colours since
/// both represent a failure state. Any other value falls back to a neutral
/// theme colour, showing the raw status text.
class StatusBadge extends StatelessWidget {
  /// Creates a status badge for [status].
  const StatusBadge(this.status, {super.key});

  /// The backend status identifier (`PAID` / `PENDING` / `UNPAID` /
  /// `FAILED`).
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, label) = switch (status) {
      'PAID' => (_paidBg, _paidFg, 'Lunas'),
      'PENDING' => (_pendingBg, _pendingFg, 'Menunggu'),
      'UNPAID' => (_unpaidBg, _unpaidFg, 'Belum Bayar'),
      'FAILED' => (_unpaidBg, _unpaidFg, 'Gagal'),
      _ => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        status,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _spacing.s,
        vertical: _spacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
