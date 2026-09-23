import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'product_browse_page.dart' show ProductBrowsePane;
export 'cart_page.dart' show CartPane;

import '../../state/cart_controller.dart';
import '../../util/responsive.dart';
import '../widgets/money_text.dart';
import '../widgets/pos_mode_selector.dart';
import '../widgets/pos_panel.dart';
import '../widgets/pos_scaffold.dart';
import 'product_browse_page.dart';
import 'cart_page.dart';
import 'pos_menu_page.dart';

/// Responsive entry shell shared by the phone and tablet POS experiences.
class PosHomePage extends ConsumerWidget {
  const PosHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(posModeProvider.select((value) => value));
    final layout = PosLayout.of(context);
    final isSimple = mode == PosMode.simple;
    final browsePane = isSimple
        ? const SimpleAmountPane()
        : const ProductBrowsePane();

    return PosScaffold(
      title: 'POS',
      showConnectivityDot: true,
      actions: [
        Center(
          child: PosModeSelector(
            isSimple: isSimple,
            onChanged: (next) =>
                ref.read(posModeProvider.notifier).state = next,
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Menu POS',
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const PosMenuPage()),
          ),
          icon: const Icon(Icons.menu),
        ),
      ],
      padding: const EdgeInsets.all(12),
      body: layout.isPhone
          ? PosPanel(child: browsePane)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: PosPanel(child: browsePane)),
                const SizedBox(width: 12),
                const Expanded(flex: 4, child: PosPanel(child: CartPane())),
              ],
            ),
      bottomBar: layout.isPhone
          ? CartSummaryBar(onTap: () => _openPhoneCart(context))
          : null,
    );
  }

  void _openPhoneCart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: CartPane()),
    );
  }
}

/// Task 35 replaces this shell placeholder with the amount keypad flow.
class SimpleAmountPane extends StatelessWidget {
  const SimpleAmountPane({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Masukkan jumlah'));
}

/// Phone-only cart affordance pinned below the active selling pane.
class CartSummaryBar extends ConsumerWidget {
  const CartSummaryBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(
      cartControllerProvider.select((cart) => cart.totalQuantity),
    );
    final subtotal = ref.watch(
      cartControllerProvider.select((cart) => cart.subTotal),
    );
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Badge(
                  label: Text('$quantity'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Lihat keranjang')),
                MoneyText(
                  subtotal,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
