import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/pos_config.dart';
import '../../models/pos_payment_method.dart';
import '../../state/pos_providers.dart';
import '../../util/currency.dart';
import '../widgets/async_view.dart';
import '../widgets/numeric_keypad.dart';
import '../widgets/payment_method_tile.dart';
import '../widgets/pos_dialog.dart';
import '../widgets/pos_scaffold.dart';

List<double> cashQuickAmounts(double amount) {
  final values = <double>[amount % 1 < .01 ? amount.roundToDouble() : amount];
  for (final step in const [1000.0, 5000.0, 10000.0, 50000.0]) {
    final next = (amount / step).ceil() * step;
    if (next > amount && !values.contains(next) && values.length < 4) {
      values.add(next);
    }
  }
  for (final value in const [100000.0, 200000.0, 500000.0, 1000000.0]) {
    if (value > amount && !values.contains(value) && values.length < 4) {
      values.add(value);
    }
  }
  while (values.length < 4) {
    values.add((values.lastOrNull ?? amount) + 50000);
  }
  return values.take(4).toList(growable: false);
}

class PaymentMethodPage extends ConsumerWidget {
  const PaymentMethodPage({super.key, required this.total});
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    final config = ref.watch(posConfigProvider.select((value) => value));
    return PosScaffold(
      title: 'Metode pembayaran',
      body: AsyncView<List<PosPaymentMethod>>(
        value: methods,
        data: (loaded) {
          final supported = loaded.where((m) => _supported(m, config));
          final internal = supported.where((m) => m.category != 'EXTERNAL');
          final external = supported.where((m) => m.category == 'EXTERNAL');
          return ListView(
            children: [
              if (internal.isNotEmpty) const Text('Pembayaran internal'),
              ...internal.map((m) => _tile(context, m)),
              if (external.isNotEmpty) const Text('Pembayaran eksternal'),
              ...external.map((m) => _tile(context, m)),
            ],
          );
        },
      ),
    );
  }

  bool _supported(PosPaymentMethod method, PosConfig config) {
    if (method.isCash) return true;
    if (method.isQris) return config.qrisGateway != null;
    return config.paymentHandler?.supportedMethods.contains(method.code) ??
        false;
  }

  Widget _tile(BuildContext context, PosPaymentMethod method) =>
      PaymentMethodTile(
        name: method.name,
        code: method.code,
        onTap: method.isCash
            ? () => showCashPaymentDialog(context, total: total)
            : null,
      );
}

Future<({double tendered, double change})?> showCashPaymentDialog(
  BuildContext context, {
  required double total,
}) => showDialog<({double tendered, double change})>(
  context: context,
  builder: (_) => CashPaymentDialog(total: total),
);

class CashPaymentDialog extends StatefulWidget {
  const CashPaymentDialog({super.key, required this.total});
  final double total;
  @override
  State<CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<CashPaymentDialog> {
  late final ValueNotifier<String> value = ValueNotifier('');
  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PosDialog(
    title: 'Pembayaran tunai',
    child: ValueListenableBuilder<String>(
      valueListenable: value,
      builder: (_, raw, child) {
        final tendered = double.tryParse(raw) ?? 0;
        final change = math.max(0, tendered - widget.total).toDouble();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total ${Money.format(widget.total)}'),
            Wrap(
              children: cashQuickAmounts(widget.total)
                  .map(
                    (amount) => TextButton(
                      onPressed: () => value.value = amount.toStringAsFixed(0),
                      child: Text(Money.format(amount)),
                    ),
                  )
                  .toList(),
            ),
            Text('Kembalian ${Money.format(change, decimals: 2)}'),
            NumericKeypad(value: value),
            FilledButton(
              onPressed: tendered >= widget.total
                  ? () => Navigator.pop(context, (
                      tendered: tendered,
                      change: change,
                    ))
                  : null,
              child: const Text('Konfirmasi'),
            ),
          ],
        );
      },
    ),
  );
}
