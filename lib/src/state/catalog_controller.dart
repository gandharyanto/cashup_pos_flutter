/// The catalogue controller: loads products and categories once per POS
/// session and filters them in memory from then on.
///
/// This is rule 8 of the performance budget in `CLAUDE.md` /
/// `flutter-pos-dev` — `selectCategory` and `setQuery` must never trigger
/// another `PosRepository.productList` call, so `visibleProducts` is a pure
/// getter over the already-loaded [CatalogState.products] rather than
/// anything that re-fetches.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/discount_item.dart';
import '../models/option_group.dart';
import '../models/payment_setting.dart';
import '../models/pos_category.dart';
import '../models/pos_product.dart';
import '../models/promotion_item.dart';
import 'pos_providers.dart';

/// The catalogue's loaded data plus in-memory filter/layout state.
class CatalogState {
  const CatalogState({
    this.products = const [],
    this.categories = const [],
    this.baseUrl,
    this.selectedCategoryId,
    this.query = '',
    this.isGrid = true,
  });

  final List<PosProduct> products;
  final List<PosCategory> categories;
  final String? baseUrl;
  final int? selectedCategoryId;
  final String query;
  final bool isGrid;

  /// [products] narrowed by [selectedCategoryId] and [query], recomputed on
  /// every read rather than cached — cheap over a single merchant's
  /// catalogue, and it keeps this the single source of truth callers (a
  /// future catalogue page) read instead of re-deriving it themselves.
  List<PosProduct> get visibleProducts {
    final normalizedQuery = query.trim().toLowerCase();
    return products
        .where((product) {
          if (selectedCategoryId != null &&
              !product.categoryIds.contains(selectedCategoryId)) {
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
    int? selectedCategoryId,
    bool clearSelectedCategoryId = false,
    String? query,
    bool? isGrid,
  }) {
    return CatalogState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      baseUrl: baseUrl ?? this.baseUrl,
      selectedCategoryId: clearSelectedCategoryId
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      query: query ?? this.query,
      isGrid: isGrid ?? this.isGrid,
    );
  }
}

/// Loads the catalogue once via [posRepositoryProvider] and exposes
/// in-memory filtering/layout operations over it.
class CatalogController extends AsyncNotifier<CatalogState> {
  @override
  Future<CatalogState> build() async {
    final repository = ref.watch(posRepositoryProvider);
    final productsFuture = repository.productList();
    final categoriesFuture = repository.categoryList();
    final productsResult = await productsFuture;
    final categoriesResult = await categoriesFuture;
    return CatalogState(
      products: productsResult.items,
      categories: categoriesResult.items,
      baseUrl: productsResult.baseUrl ?? categoriesResult.baseUrl,
    );
  }

  /// Re-fetches products and categories from scratch, e.g. after a pull to
  /// refresh — the only path that is allowed to hit the network again.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Filters [CatalogState.visibleProducts] to [categoryId] in memory. Pass
  /// `null` to clear the filter.
  void selectCategory(int? categoryId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        selectedCategoryId: categoryId,
        clearSelectedCategoryId: categoryId == null,
      ),
    );
  }

  /// Filters [CatalogState.visibleProducts] by name/SKU in memory.
  void setQuery(String query) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(query: query));
  }

  /// Toggles between grid and list layout.
  void toggleLayout() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(isGrid: !current.isGrid));
  }

  /// Fetches a product's variant/modifier groups on demand — unlike
  /// products and categories, this is naturally per-product and not part of
  /// the up-front catalogue load.
  Future<ProductOptionGroups?> optionGroups(int productId) {
    return ref.read(posRepositoryProvider).productOptionGroups(productId);
  }
}

/// The catalogue: products, categories, and their in-memory filter/layout
/// state.
final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, CatalogState>(
      CatalogController.new,
    );

/// The merchant's payment setting (tax/rounding/service charge), or `null`
/// if none has been configured yet.
final paymentSettingProvider = FutureProvider<PaymentSetting?>(
  (ref) => ref.watch(posRepositoryProvider).paymentSetting(),
);

/// Discounts currently available to apply at checkout.
final activeDiscountsProvider = FutureProvider<List<DiscountItem>>(
  (ref) => ref.watch(posRepositoryProvider).discountList(),
);

/// Promotions currently active for this merchant.
final activePromotionsProvider = FutureProvider<List<PromotionItem>>(
  (ref) => ref.watch(posRepositoryProvider).activePromotions(),
);
