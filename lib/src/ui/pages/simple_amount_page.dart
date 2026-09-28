import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pos_product.dart';
import '../../state/cart_controller.dart';
import '../../util/currency.dart';
import '../widgets/numeric_keypad.dart';
import '../widgets/pos_scaffold.dart';
import 'payment_method_page.dart';

const simpleAmountProduct = PosProduct(
  id: -1,
  name: 'Penjualan langsung',
  isPriceAdjustable: true,
  isUnlimitedStock: true,
);

class SimpleAmountPage extends StatelessWidget {
  const SimpleAmountPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const PosScaffold(title: 'Nominal sederhana', body: SimpleAmountPane());
}

class SimpleAmountPane extends ConsumerStatefulWidget {
  const SimpleAmountPane({super.key});

  @override
  ConsumerState<SimpleAmountPane> createState() => _SimpleAmountPaneState();
}

class _SimpleAmountPaneState extends ConsumerState<SimpleAmountPane> {
  final ValueNotifier<String> _value = ValueNotifier('0');

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: _value,
              builder: (context, value, _) => Text(
                Money.format(double.tryParse(value) ?? 0),
                key: const Key('simple-amount-value'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            NumericKeypad(
              value: _value,
              onSubmit: _charge,
              submitLabel: 'Tagih',
            ),
          ],
        ),
      ),
    ),
  );

  void _charge() {
    final amount = double.tryParse(_value.value) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal lebih dari nol')),
      );
      return;
    }
    final cart = ref.read(cartControllerProvider.notifier);
    cart.clear();
    cart.add(simpleAmountProduct, customBasePrice: amount);
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => PaymentMethodPage(total: amount)),
    );
  }
}
