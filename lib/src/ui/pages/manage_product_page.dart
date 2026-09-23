import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pos_repository.dart';
import '../../models/pos_category.dart';
import '../../models/pos_product.dart';
import '../../state/pos_providers.dart';
import '../../util/currency.dart';
import '../widgets/async_view.dart';
import '../widgets/pos_scaffold.dart';
import 'manage_category_page.dart';
import 'stock_movement_page.dart';

final managedProductsProvider = FutureProvider((ref) async {
  final repository = ref.watch(posRepositoryProvider);
  final products = await repository.productList(size: 100);
  final categories = await repository.categoryList(size: 100000);
  return (products: products.items, categories: categories.items);
});

String? validateProductName(String? value) =>
    value?.trim().isEmpty ?? true ? 'Nama produk wajib diisi' : null;

String? validateProductPrice(String? value) {
  final price = double.tryParse(value?.trim() ?? '');
  return price == null || price < 0 ? 'Harga tidak valid' : null;
}

class ManageProductPage extends ConsumerWidget {
  const ManageProductPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(managedProductsProvider);
    return PosScaffold(
      title: 'Manajemen produk',
      actions: [
        IconButton(
          tooltip: 'Kelola kategori',
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const ManageCategoryPage()),
          ).then((_) => ref.invalidate(managedProductsProvider)),
          icon: const Icon(Icons.category),
        ),
        IconButton(
          tooltip: 'Tambah produk',
          onPressed: () => _openEditor(context, ref, const [], null),
          icon: const Icon(Icons.add),
        ),
      ],
      body: AsyncView<({List<PosProduct> products, List<PosCategory> categories})>(
        value: data,
        onRetry: () => ref.invalidate(managedProductsProvider),
        data: (loaded) => RefreshIndicator(
          onRefresh: () => ref.refresh(managedProductsProvider.future),
          child: ListView.separated(
            itemCount: loaded.products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = loaded.products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text(
                  '${product.sku?.isNotEmpty == true ? product.sku : 'Tanpa SKU'} · Stok ${product.isUnlimitedStock ? '∞' : product.qty}',
                ),
                trailing: Text(Money.format(product.basePrice)),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageProductDetailPage(
                      productId: product.id,
                      categories: loaded.categories,
                    ),
                  ),
                ).then((_) => ref.invalidate(managedProductsProvider)),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    List<PosCategory> categories,
    PosProduct? product,
  ) async {
    final loaded = ref.read(managedProductsProvider).valueOrNull;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditorPage(
          product: product,
          categories: categories.isEmpty
              ? loaded?.categories ?? const []
              : categories,
        ),
      ),
    );
    if (saved == true) ref.invalidate(managedProductsProvider);
  }
}

final managedProductDetailProvider = FutureProvider.autoDispose
    .family<PosProduct, int>(
      (ref, id) => ref.watch(posRepositoryProvider).productDetail(id),
    );

class ManageProductDetailPage extends ConsumerWidget {
  const ManageProductDetailPage({
    super.key,
    required this.productId,
    required this.categories,
  });

  final int productId;
  final List<PosCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(managedProductDetailProvider(productId));
    return PosScaffold(
      title: 'Detail produk',
      body: AsyncView<PosProduct>(
        value: value,
        onRetry: () => ref.invalidate(managedProductDetailProvider(productId)),
        data: (product) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(product.description ?? ''),
            const SizedBox(height: 12),
            Text('Harga: ${Money.format(product.basePrice)}'),
            Text('SKU: ${product.sku?.isNotEmpty == true ? product.sku : '-'}'),
            Text(
              'Stok: ${product.isUnlimitedStock ? 'Tak terbatas' : product.qty}',
            ),
            Text(
              'Kategori: ${product.categories.isEmpty ? '-' : product.categories.map((c) => c.name).join(', ')}',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductEditorPage(
                      product: product,
                      categories: categories,
                    ),
                  ),
                );
                if (saved == true) {
                  ref.invalidate(managedProductDetailProvider(productId));
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit produk'),
            ),
            if (!product.isUnlimitedStock)
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockMovementPage(product: product),
                      ),
                    ).then(
                      (_) => ref.invalidate(
                        managedProductDetailProvider(productId),
                      ),
                    ),
                icon: const Icon(Icons.inventory_2),
                label: const Text('Kelola stok'),
              ),
          ],
        ),
      ),
    );
  }
}

class ProductEditorPage extends ConsumerStatefulWidget {
  const ProductEditorPage({super.key, this.product, required this.categories});

  final PosProduct? product;
  final List<PosCategory> categories;

  @override
  ConsumerState<ProductEditorPage> createState() => _ProductEditorPageState();
}

class _ProductEditorPageState extends ConsumerState<ProductEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _sku;
  late final TextEditingController _upc;
  late final TextEditingController _description;
  late final TextEditingController _qty;
  late final Set<int> _categoryIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name);
    _price = TextEditingController(text: product?.basePrice.toString());
    _sku = TextEditingController(text: product?.sku);
    _upc = TextEditingController(text: product?.upc);
    _description = TextEditingController(text: product?.description);
    _qty = TextEditingController(text: product?.qty.toString() ?? '0');
    _categoryIds = {...?product?.categoryIds};
  }

  @override
  void dispose() {
    for (final controller in [_name, _price, _sku, _upc, _description, _qty]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PosScaffold(
    title: widget.product == null ? 'Tambah produk' : 'Edit produk',
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nama produk'),
            validator: validateProductName,
          ),
          TextFormField(
            controller: _price,
            decoration: const InputDecoration(labelText: 'Harga'),
            keyboardType: TextInputType.number,
            validator: validateProductPrice,
          ),
          TextFormField(
            controller: _sku,
            decoration: const InputDecoration(labelText: 'SKU'),
          ),
          TextFormField(
            controller: _upc,
            decoration: const InputDecoration(labelText: 'UPC'),
          ),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Deskripsi'),
            maxLines: 3,
          ),
          if (widget.product == null)
            TextFormField(
              controller: _qty,
              decoration: const InputDecoration(labelText: 'Stok awal'),
              keyboardType: TextInputType.number,
            ),
          const SizedBox(height: 16),
          Text('Kategori', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: widget.categories
                .map(
                  (category) => FilterChip(
                    label: Text(category.name),
                    selected: _categoryIds.contains(category.id),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _categoryIds.add(category.id)
                          : _categoryIds.remove(category.id);
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final draft = PosProductDraft(
      name: _name.text.trim(),
      price: double.parse(_price.text.trim()),
      sku: _sku.text.trim(),
      upc: _upc.text.trim(),
      description: _description.text.trim(),
      qty: int.tryParse(_qty.text.trim()) ?? 0,
      categoryIds: _categoryIds.toList(growable: false),
    );
    try {
      final repository = ref.read(posRepositoryProvider);
      final product = widget.product;
      if (product == null) {
        await repository.productCreate(draft);
      } else {
        await repository.productUpdate(product.id, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan produk: $error')));
      setState(() => _saving = false);
    }
  }
}
