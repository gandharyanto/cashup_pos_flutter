import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/option_group.dart';
import '../../models/pos_product.dart';
import '../../state/cart_controller.dart';
import '../../state/catalog_controller.dart';
import '../../state/pos_providers.dart';
import '../../util/image_url.dart';
import '../../util/responsive.dart';
import '../widgets/async_view.dart';
import '../widgets/category_chip_bar.dart';
import '../widgets/numeric_keypad_sheet.dart';
import '../widgets/option_group_selector.dart';
import '../widgets/pos_bottom_sheet.dart';
import '../widgets/pos_product_tile.dart';
import '../widgets/search_field.dart';

class ProductBrowsePage extends StatelessWidget {
  const ProductBrowsePage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: ProductBrowsePane());
}

class ProductBrowsePane extends ConsumerWidget {
  const ProductBrowsePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);
    return AsyncView<CatalogState>(
      value: catalog,
      onRetry: () => ref.read(catalogControllerProvider.notifier).refresh(),
      data: (state) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SearchField(
                  initialValue: state.query,
                  onChanged: ref
                      .read(catalogControllerProvider.notifier)
                      .setQuery,
                  hintText: 'Cari produk',
                ),
              ),
              IconButton(
                tooltip: state.isGrid ? 'Tampilan daftar' : 'Tampilan grid',
                onPressed: ref
                    .read(catalogControllerProvider.notifier)
                    .toggleLayout,
                icon: Icon(state.isGrid ? Icons.view_list : Icons.grid_view),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CategoryChipBar(
            categories: state.categories
                .map((item) => (id: item.id, name: item.name))
                .toList(growable: false),
            selectedId: state.selectedCategoryId,
            onSelected: ref
                .read(catalogControllerProvider.notifier)
                .selectCategory,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.isGrid
                ? GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: PosLayout.of(context).productGridColumns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: .72,
                    ),
                    itemCount: state.visibleProducts.length,
                    itemBuilder: (_, index) => _ProductEntry(
                      product: state.visibleProducts[index],
                      baseUrl: state.baseUrl,
                      layout: ProductTileLayout.grid,
                    ),
                  )
                : ListView.separated(
                    itemCount: state.visibleProducts.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _ProductEntry(
                      product: state.visibleProducts[index],
                      baseUrl: state.baseUrl,
                      layout: ProductTileLayout.list,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductEntry extends ConsumerWidget {
  const _ProductEntry({
    required this.product,
    required this.baseUrl,
    required this.layout,
  });
  final PosProduct product;
  final String? baseUrl;
  final ProductTileLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(
      cartControllerProvider.select(
        (cart) => cart.lines.values
            .where((line) => line.product.id == product.id)
            .fold(0, (sum, line) => sum + line.quantity),
      ),
    );
    return PosProductTile(
      name: product.name,
      price: product.basePrice,
      imageUrl: resolveImageUrl(product.effectiveThumbUrl, baseUrl),
      sku: product.sku,
      stockLabel: product.isUnlimitedStock ? null : 'Stok ${product.qty}',
      outOfStock: !product.isUnlimitedStock && product.qty <= 0,
      quantityInCart: quantity,
      layout: layout,
      onTap: () => _add(context, ref),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    if (product.isVariant || product.hasModifiers) {
      final groups = await ref
          .read(catalogControllerProvider.notifier)
          .optionGroups(product.id);
      if (!context.mounted || groups == null) return;
      await showProductVariantSheet(context, product: product, groups: groups);
      return;
    }
    double? customPrice;
    if (product.isPriceAdjustable) {
      final raw = await showNumericKeypadSheet(
        context,
        title: 'Ubah harga',
        initialValue: product.basePrice.toInt().toString(),
      );
      if (raw == null || !context.mounted) return;
      customPrice = double.tryParse(raw);
    }
    ref
        .read(cartControllerProvider.notifier)
        .add(product, customBasePrice: customPrice);
  }
}

Future<void> showProductVariantSheet(
  BuildContext context, {
  required PosProduct product,
  required ProductOptionGroups groups,
}) => showPosBottomSheet<void>(
  context,
  title: product.name,
  builder: (_) => ProductVariantSheet(product: product, groups: groups),
);

class ProductVariantSheet extends StatefulWidget {
  const ProductVariantSheet({
    super.key,
    required this.product,
    required this.groups,
  });
  final PosProduct product;
  final ProductOptionGroups groups;

  @override
  State<ProductVariantSheet> createState() => _ProductVariantSheetState();
}

class _ProductVariantSheetState extends State<ProductVariantSheet> {
  final ValueNotifier<List<OptionGroupSelection>> selections = ValueNotifier(
    const [],
  );

  @override
  void dispose() {
    selections.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = [
      ...widget.groups.variantGroups,
      ...widget.groups.modifierGroups,
    ];
    final uiGroups = all
        .map(
          (group) => (
            id: group.groupId,
            name: group.name,
            multiSelect: !group.isSingleSelection,
            min: group.effectiveMinSelection,
            max: group.maxSelection <= 0
                ? group.options.length
                : group.maxSelection,
            options: group.options
                .map(
                  (o) => (
                    id: o.optionId,
                    name: o.name,
                    priceDelta: o.priceAdjustment,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    return ValueListenableBuilder<List<OptionGroupSelection>>(
      valueListenable: selections,
      builder: (context, selected, _) {
        final valid = uiGroups.every(
          (group) =>
              selected
                  .where((selection) => selection.groupId == group.id)
                  .fold(
                    0,
                    (count, selection) => count + selection.optionIds.length,
                  ) >=
              group.min,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OptionGroupSelector(
              groups: uiGroups,
              selections: selected,
              onChanged: (value) => selections.value = value,
            ),
            FilledButton(
              onPressed: valid ? () => _confirm(all, selected) : null,
              child: const Text('Tambah ke keranjang'),
            ),
          ],
        );
      },
    );
  }

  void _confirm(List<OptionGroup> groups, List<OptionGroupSelection> selected) {
    final variants = <VariantOption>[];
    final modifiers = <ModifierOption>[];
    for (final selection in selected) {
      final group = groups.firstWhere(
        (item) => item.groupId == selection.groupId,
      );
      for (final id in selection.optionIds) {
        final option = group.options.firstWhere((item) => item.optionId == id);
        if (group.groupType == OptionGroup.typeVariant) {
          variants.add(VariantOption.fromOption(option, group));
        } else {
          modifiers.add(
            ModifierOption.fromOption(
              option,
              group,
              productId: widget.product.id,
            ),
          );
        }
      }
    }
    ProviderScope.containerOf(context)
        .read(cartControllerProvider.notifier)
        .add(widget.product, variants: variants, modifiers: modifiers);
    Navigator.pop(context);
  }
}
