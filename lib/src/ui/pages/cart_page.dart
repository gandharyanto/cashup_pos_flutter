import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calc/transaction_calculator.dart';
import '../../models/discount_item.dart';
import '../../models/promotion_item.dart';
import '../../state/cart_controller.dart';
import '../../state/checkout_controller.dart';
import '../../state/pos_providers.dart';
import '../../util/calc_mappers.dart';
import '../widgets/amount_row.dart';
import '../widgets/async_view.dart';
import '../widgets/cart_line_tile.dart';
import '../widgets/pos_bottom_sheet.dart';
import '../widgets/pos_scaffold.dart';
import '../widgets/totals_panel.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PosScaffold(title: 'Keranjang', body: CartPane());
}

class CartPane extends ConsumerWidget {
  const CartPane({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(
      cartControllerProvider.select((cart) => cart.lines.keys.toList()),
    );
    final result = ref.watch(
      checkoutControllerProvider.select((checkout) => checkout.result),
    );
    if (keys.isEmpty) return const Center(child: Text('Keranjang kosong'));
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: keys.length,
            itemBuilder: (_, index) => _CartLine(cartKey: keys[index]),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => showDiscountPickerSheet(context),
                child: const Text('Diskon'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => showPromotionPickerSheet(context),
                child: const Text('Promosi'),
              ),
            ),
          ],
        ),
        TotalsPanel(
          rows: [
            AmountRow(label: 'Subtotal', amount: result.subTotal),
            if (result.discountAmount > 0)
              AmountRow(
                label: 'Diskon',
                amount: result.discountAmount,
                negative: true,
              ),
            if (result.promotionAmount > 0)
              AmountRow(
                label: 'Promosi',
                amount: result.promotionAmount,
                negative: true,
              ),
            if (result.serviceCharge > 0)
              AmountRow(label: 'Biaya layanan', amount: result.serviceCharge),
            if (result.tax > 0) AmountRow(label: 'Pajak', amount: result.tax),
            if (result.rounding != 0)
              AmountRow(label: 'Pembulatan', amount: result.rounding),
            AmountRow(
              label: 'Total',
              amount: result.totalAmount,
              emphasis: AmountEmphasis.total,
            ),
          ],
        ),
      ],
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({required this.cartKey});
  final String cartKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final line = ref.watch(cartLineProvider(cartKey));
    final saving = ref.watch(lineSavingsProvider(cartKey));
    final label = ref.watch(
      checkoutControllerProvider.select((s) => s.savings.labels[cartKey]),
    );
    if (line == null) return const SizedBox.shrink();
    return CartLineTile(
      name: line.displayName,
      unitPrice: line.effectivePrice,
      quantity: line.quantity,
      lineTotal: line.lineTotal,
      optionsSummary: line.optionsSummary.isEmpty ? null : line.optionsSummary,
      savingsAmount: saving,
      savingsLabel: label,
      imageUrl: line.product.effectiveThumbUrl,
      onQuantityChanged: (quantity) => ref
          .read(cartControllerProvider.notifier)
          .setQuantity(cartKey, quantity),
      onRemove: () => ref.read(cartControllerProvider.notifier).remove(cartKey),
    );
  }
}

Future<void> showDiscountPickerSheet(BuildContext context) =>
    showPosBottomSheet<void>(
      context,
      title: 'Pilih diskon',
      builder: (_) => const DiscountPickerSheet(),
    );

class DiscountPickerSheet extends ConsumerWidget {
  const DiscountPickerSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discounts = ref.watch(activeDiscountsProvider);
    final cartItems = ref.watch(
      cartControllerProvider.select(
        (cart) => cart.lines.values.map(toCartItemData).toList(),
      ),
    );
    final subtotal = cartItems.fold<double>(
      0,
      (sum, line) => sum + line.lineSubtotal,
    );
    return AsyncView<List<DiscountItem>>(
      value: discounts,
      data: (items) => ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, index) {
          final item = items[index];
          final enabled =
              !item.isExhausted &&
              TransactionCalculator.isDiscountEligible(
                toDiscountInput(item),
                cartItems,
                subtotal,
              );
          return ListTile(
            enabled: enabled,
            title: Text(item.name),
            onTap: enabled
                ? () {
                    ref
                        .read(checkoutControllerProvider.notifier)
                        .applyDiscount(item);
                    Navigator.pop(context);
                  }
                : null,
          );
        },
      ),
    );
  }
}

Future<void> showPromotionPickerSheet(BuildContext context) =>
    showPosBottomSheet<void>(
      context,
      title: 'Promosi',
      builder: (_) => const PromotionPickerSheet(),
    );

class PromotionPickerSheet extends ConsumerWidget {
  const PromotionPickerSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotions = ref.watch(activePromotionsProvider);
    final cartItems = ref.watch(
      cartControllerProvider.select(
        (cart) => cart.lines.values.map(toCartItemData).toList(),
      ),
    );
    final subtotal = cartItems.fold<double>(
      0,
      (sum, line) => sum + line.lineSubtotal,
    );
    return AsyncView<List<PromotionItem>>(
      value: promotions,
      data: (items) => ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, index) {
          final item = items[index];
          final input = toPromotionInputs([item]).single;
          final enabled = TransactionCalculator.isPromotionEligible(
            input,
            cartItems,
            subtotal,
          );
          return ListTile(
            enabled: enabled,
            title: Text(item.name),
            subtitle: item.isBuyXGetY ? const Text('Pilih hadiah') : null,
            onTap: !enabled
                ? null
                : item.isBuyXGetY
                ? () => showRewardSelectorSheet(context, promotion: item)
                : () => Navigator.pop(context),
          );
        },
      ),
    );
  }
}

Future<void> showRewardSelectorSheet(
  BuildContext context, {
  required PromotionItem promotion,
}) => showPosBottomSheet<void>(
  context,
  title: 'Pilih hadiah',
  builder: (_) => RewardSelectorSheet(promotion: promotion),
);

class RewardSelectorSheet extends ConsumerWidget {
  const RewardSelectorSheet({super.key, required this.promotion});
  final PromotionItem promotion;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(
      cartControllerProvider.select((cart) => cart.lines),
    );
    final eligible = lines.values
        .where(
          (line) =>
              promotion.rewardProductIds.isEmpty ||
              promotion.rewardProductIds.contains(line.product.id),
        )
        .toList();
    return ListView.builder(
      shrinkWrap: true,
      itemCount: eligible.length,
      itemBuilder: (_, index) {
        final line = eligible[index];
        return ListTile(
          title: Text(line.displayName),
          onTap: () {
            ref.read(checkoutControllerProvider.notifier).selectReward(
              promotion.id,
              {line.cartKey: promotion.rewardQty ?? 1},
            );
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
