/// The product catalogue: one network fetch, then in-memory filtering.
///
/// Performance rule 8 of the package's performance budget: category and
/// search filtering must never trigger another `PosRepository.productList`
/// or `categoryList` call. [CatalogController.build] is the only place that
/// fetches; [CatalogController.selectCategory] and
/// [CatalogController.setQuery] only update [CatalogState] fields, and
/// [CatalogState.visibleProducts] recomputes the filtered list from the
/// already-loaded [CatalogState.products] every time it is read.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/option_group.dart';
import '../models/pos_category.dart';
import '../models/pos_product.dart';
import 'pos_providers.dart';

/// The catalogue's loaded data plus the filters currently applied to it.
///
/// [visibleProducts] is a getter, not a field, so it always reflects the
/// current [selectedCategoryId] / [query] against [products] without any
/// extra fetch or cached derived list to keep in sync.
class CatalogState {
  const CatalogState({
    this.products = const [],
    this.categories = const [],
    this.baseUrl,
    this.selectedCategoryId,
    this.query = '',
    this.isGrid = true,
  });

  /// Every product loaded for the merchant, unfiltered.
  final List<PosProduct> products;

  /// Every category loaded for the merchant.
  final List<PosCategory> categories;

  /// Relative image paths in [products] resolve against this.
  final String? baseUrl;

  /// `null` means "all categories".
  final int? selectedCategoryId;

  /// Matched case-insensitively against a product's name and SKU.
  final String query;

  /// Grid vs. list layout for the product picker. Purely a UI preference —
  /// never sent to the backend.
  final bool isGrid;

  /// [products] filtered by [selectedCategoryId] and [query], computed fresh
  /// on every read. Never triggers a network request.
  List<PosProduct> get visibleProducts {
    final categoryId = selectedCategoryId;
    final normalizedQuery = query.trim().toLowerCase();
    return products
        .where((product) {
          if (categoryId != null && !product.categoryIds.contains(categoryId)) {
            return false;
          }
          if (normalizedQuery.isEmpty) return true;
          final name = product.name.toLowerCase();
          final sku = product.sku?.toLowerCase() ?? '';
          return name.contains(normalizedQuery) ||
              sku.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  CatalogState copyWith({
    List<PosProduct>? products,
    List<PosCategory>? categories,
    String? baseUrl,
    // A nullable field needs a way to be explicitly cleared, which a plain
    // `int?` parameter can't distinguish from "leave unchanged" — wrapping
    // it in a getter function is the usual workaround.
    int? Function()? selectedCategoryId,
    String? query,
    bool? isGrid,
  }) => CatalogState(
    products: products ?? this.products,
    categories: categories ?? this.categories,
    baseUrl: baseUrl ?? this.baseUrl,
    selectedCategoryId: selectedCategoryId != null
        ? selectedCategoryId()
        : this.selectedCategoryId,
    query: query ?? this.query,
    isGrid: isGrid ?? this.isGrid,
  );
}

/// Loads the catalogue once and exposes in-memory filtering over it.
class CatalogController extends AsyncNotifier<CatalogState> {
  @override
  Future<CatalogState> build() => _fetch(previous: null);

  /// Re-fetches products and categories from the network, preserving the
  /// currently applied filters and layout. Unlike [selectCategory] /
  /// [setQuery], this is the only other place (besides [build]) that talks
  /// to [PosRepository].
  Future<void> refresh() async {
    final previous = state.valueOrNull;
    state = const AsyncValue<CatalogState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _fetch(previous: previous));
  }

  Future<CatalogState> _fetch({required CatalogState? previous}) async {
    final repository = ref.read(posRepositoryProvider);
    final productsFuture = repository.productList();
    final categoriesFuture = repository.categoryList();
    final productsResult = await productsFuture;
    final categoriesResult = await categoriesFuture;
    return CatalogState(
      products: productsResult.items,
      categories: categoriesResult.items,
      baseUrl: productsResult.baseUrl,
      selectedCategoryId: previous?.selectedCategoryId,
      query: previous?.query ?? '',
      isGrid: previous?.isGrid ?? true,
    );
  }

  /// Filters [CatalogState.visibleProducts] to [categoryId]; `null` clears
  /// the filter. Purely in-memory — never refetches.
  void selectCategory(int? categoryId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedCategoryId: () => categoryId));
  }

  /// Filters [CatalogState.visibleProducts] by name/SKU. Purely in-memory —
  /// never refetches.
  void setQuery(String query) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(query: query));
  }

  /// Toggles between grid and list layout for the product picker.
  void toggleLayout() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(isGrid: !current.isGrid));
  }

  /// Fetches a product's variant/modifier groups on demand — unlike
  /// products/categories, option groups are not preloaded because most
  /// products in a catalogue have none.
  Future<ProductOptionGroups?> optionGroups(int productId) =>
      ref.read(posRepositoryProvider).productOptionGroups(productId);
}
