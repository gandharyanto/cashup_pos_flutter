import 'package:flutter/widgets.dart';

import 'amount_row.dart';

/// A stack of [AmountRow]s (subtotal, discount, tax, total, ...) with an
/// optional footer widget below the last row (e.g. a payment method note).
class TotalsPanel extends StatelessWidget {
  const TotalsPanel({super.key, required this.rows, this.footer});

  final List<AmountRow> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [...rows, ?footer],
    );
  }
}
