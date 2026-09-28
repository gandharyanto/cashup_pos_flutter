/// The seam between everything above `data/` and the `/pos/*` backend.
///
/// Ported from `pos-core/.../data/repositories/PosRepositoryImpl.kt` — only
/// the request/response shapes carry over, not the `LiveData` plumbing (the
/// Kotlin source predates coroutines in most of this file and wraps every
/// call in a `LiveData<ApiResponse<T>>`; Dart's `Future` plus
/// [PosException] replaces that entirely).
///
/// This is the reversible half of the pure-online decision documented in
/// `CLAUDE.md`: a future caching or outbox-backed implementation can
/// `implement PosRepository` without state or UI code changing at all.
/// Nothing above `data/` may reach past this interface to [PosApiClient].
library;

import '../models/create_transaction_request.dart';
import '../models/discount_item.dart';
import '../models/option_group.dart';
import '../models/paged_result.dart';
import '../models/payment_setting.dart';
import '../models/pos_area.dart';
import '../models/pos_category.dart';
import '../models/pos_lookup_page.dart';
import '../models/pos_merchant_summary.dart';
import '../models/pos_payment_method.dart';
import '../models/pos_product.dart';
import '../models/promotion_item.dart';
import '../models/stock_movement.dart';
import '../models/summary_report.dart';
import '../models/transaction_details.dart';
import '../models/transaction_summary.dart';
import 'pos_api_client.dart';

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

  // ── Area & merchant directory (placeholder paths, confirmed item shape) ──
  //
  // No such endpoint exists anywhere in the pinned Kotlin source this
  // package ports from — see the doc comments on [PosRepositoryImpl]'s
  // implementations for details. Designed to be swappable with no ripple
  // beyond this layer once the paths are confirmed. The response envelope
  // (`PosLookupPage`) is taken from a real backend sample, distinct from
  // the rest of `/pos/*`'s `PagedResult` envelope — see that class's doc.

  Future<PosLookupPage<PosArea>> areaList({int size = 100, String? keyword});
  Future<PosLookupPage<PosMerchantSummary>> merchantList({
    int size = 100,
    String? keyword,
  });
  Future<PosLookupPage<PosMerchantSummary>> merchantsByArea({
    required int areaId,
    int size = 100,
    String? keyword,
  });
}

/// The `pos/product/add` / `pos/product/update` payload.
///
/// One carrier serves both endpoints — [PosRepositoryImpl] adds `productId`
/// for an update and `qty` for a create, mirroring the two distinct request
/// shapes `PosCreateProductRequest` / `PosUpdateProductRequest` on the
/// Kotlin side (the update request has no `qty` field: stock is changed
/// only through [PosRepository.stockUpdate]).
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

  /// Only sent on create — see the class doc.
  final int qty;
  final List<int>? categoryIds;
}

/// The `pos/category/single/add` / `pos/category/update` payload.
class PosCategoryDraft {
  const PosCategoryDraft({
    required this.name,
    this.image = '',
    this.description = '',
  });

  final String name;
  final String image;
  final String description;
}
