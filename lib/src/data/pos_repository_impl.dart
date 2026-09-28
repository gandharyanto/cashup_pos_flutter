/// The online `PosRepository` — every method maps one endpoint from the
/// spec's "API Surface Consumed" table onto [PosApiClient].
///
/// Ported from `pos-core/.../data/repositories/PosRepositoryImpl.kt`: only
/// the request/response shapes carry over, never the `LiveData` plumbing —
/// every method here is a plain `Future`. Query parameter names and path
/// templates are taken from `pos-core/.../data/network/PosService.kt`.
///
/// `productOptionGroups` intentionally calls only
/// `pos/product/{productId}/option-groups`: the Kotlin repository's
/// `getProductVariants` / `getProductModifiers` methods (mapped from
/// `pos/product/{id}/variants` and `pos/product/{id}/modifiers`) never reach
/// the real backend — they return `DummyVariantDataProvider` data and are
/// legacy/unused. The option-groups endpoint alone returns the
/// `ProductOptionGroups` shape this interface exposes.
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
import '../util/num_utils.dart';
import '../util/pos_date_utils.dart';
import 'pos_api_client.dart';
import 'pos_exception.dart';
import 'pos_repository.dart';

class PosRepositoryImpl implements PosRepository {
  PosRepositoryImpl(this._api);

  final PosApiClient _api;

  // ── Product ────────────────────────────────────────────────────────────

  @override
  Future<PagedResult<PosProduct>> productList({
    int size = 100,
    int? categoryId,
    String? keyword,
    String? upc,
    String? sku,
    String? sortBy,
    String? sortDir,
  }) async {
    final response = await _api.get(
      'pos/product/list',
      query: _query({
        'size': size,
        'categoryId': categoryId,
        'keyword': keyword,
        'upc': upc,
        'sku': sku,
        'sortBy': sortBy,
        'sortDir': sortDir,
      }),
    );
    return PagedResult.fromJson(response, PosProduct.fromJson);
  }

  @override
  Future<PosProduct> productDetail(int productId) async {
    final response = await _api.get('pos/product/detail/$productId');
    return PosProduct.fromJson(_requireData(response));
  }

  @override
  Future<int> productCreate(PosProductDraft draft) async {
    final response = await _api.post(
      'pos/product/add',
      body: draft.toCreateJson(),
    );
    return _requireId(_requireData(response), 'productId');
  }

  @override
  Future<void> productUpdate(int productId, PosProductDraft draft) async {
    await _api.put('pos/product/update', body: draft.toUpdateJson(productId));
  }

  @override
  Future<void> productDelete(int productId) async {
    await _api.delete('pos/product/delete/$productId');
  }

  @override
  Future<ProductOptionGroups?> productOptionGroups(int productId) async {
    final response = await _api.get('pos/product/$productId/option-groups');
    final data = response['data'];
    if (data is! Map) return null;
    return ProductOptionGroups.fromJson(Map<String, dynamic>.from(data));
  }

  // ── Category ───────────────────────────────────────────────────────────

  @override
  Future<PagedResult<PosCategory>> categoryList({int size = 100}) async {
    final response = await _api.get('pos/category/list', query: {'size': size});
    return PagedResult.fromJson(response, PosCategory.fromJson);
  }

  @override
  Future<PosCategory> categoryDetail(int categoryId) async {
    final response = await _api.get('pos/category/detail/$categoryId');
    return PosCategory.fromJson(_requireData(response));
  }

  @override
  Future<int> categoryCreate(PosCategoryDraft draft) async {
    final response = await _api.post(
      'pos/category/single/add',
      body: draft.toCreateJson(),
    );
    return _requireId(_requireData(response), 'categoryId');
  }

  @override
  Future<void> categoryUpdate(int categoryId, PosCategoryDraft draft) async {
    await _api.put('pos/category/update', body: draft.toUpdateJson(categoryId));
  }

  @override
  Future<void> categoryDelete(int categoryId) async {
    await _api.delete('pos/category/delete/$categoryId');
  }

  // ── Stock ──────────────────────────────────────────────────────────────

  @override
  Future<void> stockUpdate({
    required int productId,
    required int qty,
    required String updateType,
  }) async {
    await _api.put(
      'pos/stock/update',
      body: {'productId': productId, 'qty': qty, 'updateType': updateType},
    );
  }

  @override
  Future<PagedResult<StockMovementRow>> stockMovements({
    required int productId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _api.get(
      'pos/stock-movement/product/list',
      query: {
        'productId': productId,
        'startDate': PosDates.apiDate(startDate),
        'endDate': PosDates.apiDate(endDate),
      },
    );
    return PagedResult.fromJson(response, StockMovementRow.fromJson);
  }

  // ── Payment setting & methods ─────────────────────────────────────────

  @override
  Future<PaymentSetting?> paymentSetting() async {
    final response = await _api.get('pos/payment-setting');
    final data = response['data'];
    if (data is! Map) return null;
    return PaymentSetting.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> paymentSettingCreate(PaymentSetting setting) async {
    await _api.post(
      'pos/payment-setting/create',
      body: _paymentSettingCreateJson(setting),
    );
  }

  @override
  Future<void> paymentSettingUpdate(PaymentSetting setting) async {
    await _api.put(
      'pos/payment-setting/update',
      body: _paymentSettingUpdateJson(setting),
    );
  }

  @override
  Future<List<PosPaymentMethod>> paymentMethods() async {
    final response = await _api.get('pos/payment-method/merchant/list');
    final data = response['data'];
    if (data is! Map) return const [];
    return PosPaymentMethod.listFromJson(Map<String, dynamic>.from(data)).all;
  }

  // ── Transaction ────────────────────────────────────────────────────────

  @override
  Future<CreatedTransaction> transactionCreate(
    CreateTransactionRequest request,
  ) async {
    final response = await _api.post(
      'pos/transaction/create',
      body: request.toJson(),
    );
    return CreatedTransaction.fromJson(_requireData(response));
  }

  @override
  Future<TransactionDetails> transactionDetail(int transactionId) async {
    final response = await _api.get('pos/transaction/detail/$transactionId');
    return TransactionDetails.fromJson(_requireData(response));
  }

  @override
  Future<void> transactionUpdate(
    String merchantTrxId,
    UpdateTransactionRequest request,
  ) async {
    await _api.put(
      'pos/transaction/update/$merchantTrxId',
      body: request.toJson(),
    );
  }

  @override
  Future<PagedResult<TransactionSummaryRow>> transactionList({
    required int page,
    required int size,
    required DateTime startDate,
    required DateTime endDate,
    String sortBy = 'transactionDate',
    String sortType = 'DESC',
  }) async {
    final response = await _api.get(
      'pos/transaction/list',
      query: {
        'page': page,
        'size': size,
        'startDate': PosDates.apiDate(startDate),
        'endDate': PosDates.apiDate(endDate),
        'sortBy': sortBy,
        'sortType': sortType,
      },
    );
    return PagedResult.fromJson(response, TransactionSummaryRow.fromJson);
  }

  // ── Reports, discounts & promotions ──────────────────────────────────

  @override
  Future<SummaryReportData> summaryReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _api.get(
      'pos/summary-report/list',
      query: {
        'startDate': PosDates.apiDate(startDate),
        'endDate': PosDates.apiDate(endDate),
      },
    );
    return SummaryReportData.fromJson(_requireData(response));
  }

  @override
  Future<List<DiscountItem>> discountList() async {
    final response = await _api.get('pos/discount/available');
    return DiscountItem.listFromJson(response['data']);
  }

  @override
  Future<List<PromotionItem>> activePromotions() async {
    final response = await _api.get('pos/promotion/active');
    return PromotionItem.listFromJson(response['data']);
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Unwraps the envelope's `data` object, throwing when it is missing or
  /// not an object — the shape every non-list, non-nullable endpoint needs.
  Map<String, dynamic> _requireData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const PosException(
        kind: PosErrorKind.badResponse,
        message: 'Response envelope is missing "data"',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  /// Reads an integer id out of a create response's `data` object.
  int _requireId(Map<String, dynamic> data, String key) {
    final id = asInt(data[key]);
    if (id == null) {
      throw PosException(
        kind: PosErrorKind.badResponse,
        message: 'Response "data" is missing "$key"',
      );
    }
    return id;
  }

  /// Drops null entries so optional query parameters are omitted from the
  /// request rather than sent as literal `null`.
  Map<String, dynamic> _query(Map<String, dynamic> raw) =>
      Map.fromEntries(raw.entries.where((entry) => entry.value != null));

  /// The `pos/payment-setting/create` body.
  ///
  /// Deliberately narrower than `PaymentSetting.toJson()`: mirrors
  /// `PosCreatePaymentSettingRequest.kt`, which has neither
  /// `paymentSettingId` (not assigned yet) nor `receiptFooterText` (not a
  /// field on that DTO at all).
  Map<String, dynamic> _paymentSettingCreateJson(PaymentSetting setting) => {
    'isPriceIncludeTax': setting.isPriceIncludeTax,
    'isRounding': setting.isRounding,
    'roundingTarget': setting.roundingTarget,
    'roundingType': setting.roundingType,
    'isServiceCharge': setting.isServiceCharge,
    'serviceChargePercentage': setting.serviceChargePercentage,
    'serviceChargeAmount': setting.serviceChargeAmount,
    'isTax': setting.isTax,
    'taxPercentage': setting.taxPercentage,
    'taxName': setting.taxName,
  };

  /// The `pos/payment-setting/update` body.
  ///
  /// Mirrors `PosUpdatePaymentSettingRequest.kt`: carries `paymentSettingId`
  /// (unlike create), but still no `receiptFooterText` — that DTO doesn't
  /// declare the field either.
  Map<String, dynamic> _paymentSettingUpdateJson(PaymentSetting setting) => {
    'paymentSettingId': setting.paymentSettingId,
    ..._paymentSettingCreateJson(setting),
  };
}
