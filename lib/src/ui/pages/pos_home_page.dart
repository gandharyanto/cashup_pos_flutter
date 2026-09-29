import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'product_browse_page.dart' show ProductBrowsePane;
export 'cart_page.dart' show CartPane;

import '../../state/cart_controller.dart';
import '../../util/responsive.dart';
import '../widgets/money_text.dart';
import '../widgets/pos_mode_selector.dart';
import '../widgets/pos_panel.dart';
import 'product_browse_page.dart';
import 'cart_page.dart';
import 'pos_menu_page.dart';
import 'simple_amount_page.dart';

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

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
        title: const _StoreLocationTitle(),
        actions: [
          if (!layout.isPhone)
            Center(
              child: PosModeSelector(
                isSimple: isSimple,
                onChanged: (next) =>
                    ref.read(posModeProvider.notifier).state = next,
              ),
            ),
          IconButton(
            tooltip: 'Menu POS',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const PosMenuPage()),
            ),
            icon: const Icon(Icons.menu_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          layout.isPhone ? 16 : 12,
          8,
          layout.isPhone ? 16 : 12,
          12,
        ),
        child: layout.isPhone
            ? browsePane
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: PosPanel(child: browsePane)),
                  const SizedBox(width: 12),
                  const Expanded(flex: 4, child: PosPanel(child: CartPane())),
                ],
              ),
      ),
      bottomNavigationBar: layout.isPhone
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

class _StoreLocationTitle extends StatelessWidget {
  const _StoreLocationTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.storefront_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pesanan dari',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Cashup POS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
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
    final theme = Theme.of(context);
    final hasItems = quantity > 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Material(
          color: hasItems
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: hasItems ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasItems
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.18)
                          : theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$quantity',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: hasItems
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasItems ? 'Lihat keranjang' : 'Keranjang masih kosong',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: hasItems
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasItems) ...[
                    MoneyText(
                      subtotal,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
