/// A stacked list of [AmountRow]s, used for the cart totals summary, the
/// receipt breakdown and the checkout confirmation.
library;

import 'package:flutter/material.dart';

import 'amount_row.dart';

/// A vertical stack of [rows], with an optional [footer] below them (e.g. a
/// "bayar sekarang" button on the checkout confirmation).
class TotalsPanel extends StatelessWidget {
  /// Creates a totals panel.
  const TotalsPanel({super.key, required this.rows, this.footer});

  /// The amount rows, top to bottom.
  final List<AmountRow> rows;

  /// Optional content rendered below [rows].
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...rows, ?footer],
    );
  }
}
