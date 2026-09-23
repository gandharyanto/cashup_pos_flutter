/// The seam between the pure-online decision and everything above `data/`.
///
/// `PosRepositoryImpl` is the only implementation today — there is no local
/// cache or outbox (see the package's `CLAUDE.md`: "pure online" is an
/// explicit product decision, and a dropped connection halts sales rather
/// than queuing). This abstract class exists anyway so a future caching or
/// outbox implementation is a drop-in replacement: `state/` and `ui/` code
/// must depend on [PosRepository], never reach past it to `PosApiClient`.
library;

import '../models/create_transaction_request.dart';
import '../models/discount_item.dart';
import '../models/option_group.dart';
import '../models/paged_result.dart';
import '../models/payment_setting.dart';
import '../models/pos_category.dart';
import '../models/pos_payment_method.dart';
import '../models/pos_product.dart';
import '../models/promotion_item.dart';
import '../models/stock_movement.dart';
import '../models/summary_report.dart';
import '../models/transaction_details.dart';
import '../models/transaction_summary.dart';

/// The fields needed to create or update a product.
///
/// Mirrors `PosCreateProductRequest` / `PosUpdateProductRequest`
/// (`pos-core/.../data/request/`) — the only difference between the two
/// wire shapes is [qty], which the update request does not carry.
class PosProductDraft {
  const PosProductDraft({
    required this.name,
    required this.price,
    this.sku = '',
    this.upc = '',
    this.imageUrl = '',
    this.imageThumbUrl = '',
    this.description = '',
    this.qty = 0,
    this.categoryIds,
  });

  final String name;
  final double price;
  final String sku;
  final String upc;
  final String imageUrl;
  final String imageThumbUrl;
  final String description;

  /// Sent only on create — `PosUpdateProductRequest` has no `qty` field.
  final int qty;

  /// Omitted from the request body entirely when `null`, matching the
  /// Kotlin request's `List<Long>? = null` default.
  final List<int>? categoryIds;

  /// The `pos/product/add` request body.
  Map<String, dynamic> toCreateJson() => {
    'name': name,
    'price': price,
    'sku': sku,
    'upc': upc,
    'imageUrl': imageUrl,
    'imageThumbUrl': imageThumbUrl,
    'description': description,
    'qty': qty,
    if (categoryIds != null) 'categoryIds': categoryIds,
  };

  /// The `pos/product/update` request body.
  Map<String, dynamic> toUpdateJson(int productId) => {
    'productId': productId,
    'name': name,
    'price': price,
    'sku': sku,
    'upc': upc,
    'imageUrl': imageUrl,
    'imageThumbUrl': imageThumbUrl,
    'description': description,
    if (categoryIds != null) 'categoryIds': categoryIds,
  };
}

/// The fields needed to create or update a category.
///
/// Mirrors `PosCreateCategoryRequest` / `PosUpdateCategoryRequest` — the two
/// wire shapes differ only by the `categoryId` path/body value the update
/// request carries.
class PosCategoryDraft {
  const PosCategoryDraft({
    required this.name,
    this.image = '',
    this.description = '',
  });

  final String name;
  final String image;
  final String description;

  /// The `pos/category/single/add` request body.
  Map<String, dynamic> toCreateJson() => {
    'name': name,
    'image': image,
    'description': description,
  };

  /// The `pos/category/update` request body.
  Map<String, dynamic> toUpdateJson(int categoryId) => {
    'categoryId': categoryId,
    'name': name,
    'image': image,
    'description': description,
  };
}

/// Online access to every `/pos/*` operation the SDK needs.
///
/// See the library doc comment above: this is the reversibility seam for the
/// pure-online decision, not an abstraction over multiple live backends.
abstract class PosRepository {
  Future<PagedResult<PosProduct>> productList({
    int size = 100,
    int? categoryId,
    String? keyword,
    String? upc,
    String? sku,
    String? sortBy,
    String? sortDir,
  });

  Future<PosProduct> productDetail(int productId);

  Future<int> productCreate(PosProductDraft draft);

  Future<void> productUpdate(int productId, PosProductDraft draft);

  Future<void> productDelete(int productId);

  Future<ProductOptionGroups?> productOptionGroups(int productId);

  Future<PagedResult<PosCategory>> categoryList({int size = 100});

  Future<PosCategory> categoryDetail(int categoryId);

  Future<int> categoryCreate(PosCategoryDraft draft);

  Future<void> categoryUpdate(int categoryId, PosCategoryDraft draft);

  Future<void> categoryDelete(int categoryId);

  Future<void> stockUpdate({
    required int productId,
    required int qty,
    required String updateType,
  });

  Future<PagedResult<StockMovementRow>> stockMovements({
    required int productId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<PaymentSetting?> paymentSetting();

  Future<void> paymentSettingCreate(PaymentSetting setting);

  Future<void> paymentSettingUpdate(PaymentSetting setting);

  Future<List<PosPaymentMethod>> paymentMethods();

  Future<CreatedTransaction> transactionCreate(
    CreateTransactionRequest request,
  );

  Future<TransactionDetails> transactionDetail(int transactionId);

  Future<void> transactionUpdate(
    String merchantTrxId,
    UpdateTransactionRequest request,
  );

  Future<PagedResult<TransactionSummaryRow>> transactionList({
    required int page,
    required int size,
    required DateTime startDate,
    required DateTime endDate,
    String sortBy = 'transactionDate',
    String sortType = 'DESC',
  });

  Future<SummaryReportData> summaryReport({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<List<DiscountItem>> discountList();

  Future<List<PromotionItem>> activePromotions();
}
