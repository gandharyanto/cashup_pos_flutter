/// The online [PosRepository] implementation — every method is a thin
/// mapping from one `/pos/*` endpoint (path, query/body shape, response
/// envelope) onto the interface's plain-data return type.
///
/// Endpoint paths and parameter names are taken from
/// `pos-core/.../data/network/PosService.kt`, cross-checked against
/// `PosRepositoryImpl.kt`'s call sites (the `LiveData` plumbing there is
/// replaced by `Future` + [PosException] here).
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

  // ── Product ───────────────────────────────────────────────────────────

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
    final json = await _api.get(
      'pos/product/list',
      query: {
        'size': size,
        'categoryId': ?categoryId,
        'keyword': ?keyword,
        'upc': ?upc,
        'sku': ?sku,
        'sortBy': ?sortBy,
        'sortDir': ?sortDir,
      },
    );
    return PagedResult.fromJson(json, PosProduct.fromJson);
  }

  @override
  Future<PosProduct> productDetail(int productId) async {
    final json = await _api.get('pos/product/detail/$productId');
    return PosProduct.fromJson(_requireMap(json, 'product detail'));
  }

  @override
  Future<int> productCreate(PosProductDraft draft) async {
    final json = await _api.post(
      'pos/product/add',
      body: {
        'name': draft.name,
        'price': draft.price,
        'sku': draft.sku,
        'upc': draft.upc,
        'imageUrl': draft.imageUrl,
        'imageThumbUrl': draft.imageThumbUrl,
        'description': draft.description,
        'qty': draft.qty,
        if (draft.categoryIds != null) 'categoryIds': draft.categoryIds,
      },
    );
    final id = asInt(_requireMap(json, 'created product')['productId']);
    if (id == null) {
      throw const PosException(
        kind: PosErrorKind.badResponse,
        message: 'Missing created product id',
      );
    }
    return id;
  }

  @override
  Future<void> productUpdate(int productId, PosProductDraft draft) async {
    await _api.put(
      'pos/product/update',
      body: {
        'productId': productId,
        'name': draft.name,
        'price': draft.price,
        'sku': draft.sku,
        'upc': draft.upc,
        'imageUrl': draft.imageUrl,
        'imageThumbUrl': draft.imageThumbUrl,
        'description': draft.description,
        if (draft.categoryIds != null) 'categoryIds': draft.categoryIds,
      },
    );
  }

  @override
  Future<void> productDelete(int productId) async {
    await _api.delete('pos/product/delete/$productId');
  }

  @override
  Future<ProductOptionGroups?> productOptionGroups(int productId) async {
    final json = await _api.get('pos/product/$productId/option-groups');
    final data = json['data'];
    if (data is! Map) return null;
    return ProductOptionGroups.fromJson(Map<String, dynamic>.from(data));
  }

  // ── Category ──────────────────────────────────────────────────────────

  @override
  Future<PagedResult<PosCategory>> categoryList({int size = 100}) async {
    final json = await _api.get('pos/category/list', query: {'size': size});
    return PagedResult.fromJson(json, PosCategory.fromJson);
  }

  @override
  Future<PosCategory> categoryDetail(int categoryId) async {
    final json = await _api.get('pos/category/detail/$categoryId');
    return PosCategory.fromJson(_requireMap(json, 'category detail'));
  }

  @override
  Future<int> categoryCreate(PosCategoryDraft draft) async {
    final json = await _api.post(
      'pos/category/single/add',
      body: {
        'name': draft.name,
        'image': draft.image,
        'description': draft.description,
      },
    );
    final id = asInt(_requireMap(json, 'created category')['categoryId']);
    if (id == null) {
      throw const PosException(
        kind: PosErrorKind.badResponse,
        message: 'Missing created category id',
      );
    }
    return id;
  }

  @override
  Future<void> categoryUpdate(int categoryId, PosCategoryDraft draft) async {
    await _api.put(
      'pos/category/update',
      body: {
        'categoryId': categoryId,
        'name': draft.name,
        'image': draft.image,
        'description': draft.description,
      },
    );
  }

  @override
  Future<void> categoryDelete(int categoryId) async {
    await _api.delete('pos/category/delete/$categoryId');
  }

  // ── Stock ─────────────────────────────────────────────────────────────

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
    final json = await _api.get(
      'pos/stock-movement/product/list',
      query: {
        'productId': productId,
        'startDate': PosDates.apiDate(startDate),
        'endDate': PosDates.apiDate(endDate),
      },
    );
    return PagedResult.fromJson(json, StockMovementRow.fromJson);
  }

  // ── Payment setting & methods ────────────────────────────────────────

  @override
  Future<PaymentSetting?> paymentSetting() async {
    final json = await _api.get('pos/payment-setting');
    final data = json['data'];
    if (data is! Map) return null;
    return PaymentSetting.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<void> paymentSettingCreate(PaymentSetting setting) async {
    await _api.post(
      'pos/payment-setting/create',
      body: _paymentSettingJson(setting),
    );
  }

  @override
  Future<void> paymentSettingUpdate(PaymentSetting setting) async {
    await _api.put(
      'pos/payment-setting/update',
      body: {
        'paymentSettingId': setting.paymentSettingId,
        ..._paymentSettingJson(setting),
      },
    );
  }

  /// The fields common to `PosCreatePaymentSettingRequest` and
  /// `PosUpdatePaymentSettingRequest` — neither carries `receiptFooterText`,
  /// unlike the read-side `PaymentSetting` model, so this is a dedicated
  /// mapping rather than a reuse of `PaymentSetting.toJson`.
  Map<String, dynamic> _paymentSettingJson(PaymentSetting setting) => {
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

  @override
  Future<List<PosPaymentMethod>> paymentMethods() async {
    final json = await _api.get('pos/payment-method/merchant/list');
    final data = json['data'];
    if (data is! Map) return const [];
    return PosPaymentMethod.listFromJson(Map<String, dynamic>.from(data)).all;
  }

  // ── Transaction ───────────────────────────────────────────────────────

  @override
  Future<CreatedTransaction> transactionCreate(
    CreateTransactionRequest request,
  ) async {
    final json = await _api.post(
      'pos/transaction/create',
      body: request.toJson(),
    );
    return CreatedTransaction.fromJson(
      _requireMap(json, 'created transaction'),
    );
  }

  @override
  Future<TransactionDetails> transactionDetail(int transactionId) async {
    final json = await _api.get('pos/transaction/detail/$transactionId');
    return TransactionDetails.fromJson(_requireMap(json, 'transaction detail'));
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
    final json = await _api.get(
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
    return PagedResult.fromJson(json, TransactionSummaryRow.fromJson);
  }

  // ── Reporting, discounts & promotions ───────────────────────────────────

  @override
  Future<SummaryReportData> summaryReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final json = await _api.get(
      'pos/summary-report/list',
      query: {
        'startDate': PosDates.apiDate(startDate),
        'endDate': PosDates.apiDate(endDate),
      },
    );
    final data = json['data'];
    if (data is! Map) return const SummaryReportData();
    return SummaryReportData.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<List<DiscountItem>> discountList() async {
    final json = await _api.get('pos/discount/available');
    return DiscountItem.listFromJson(json['data']);
  }

  @override
  Future<List<PromotionItem>> activePromotions() async {
    final json = await _api.get('pos/promotion/active');
    return PromotionItem.listFromJson(json['data']);
  }

  // ── Shared ────────────────────────────────────────────────────────────

  /// Unwraps the envelope's `data` object, throwing the error every method
  /// that requires one must raise when the backend omits it.
  Map<String, dynamic> _requireMap(Map<String, dynamic> json, String what) {
    final data = json['data'];
    if (data is! Map) {
      throw PosException(
        kind: PosErrorKind.badResponse,
        message: 'Missing $what data',
      );
    }
    return Map<String, dynamic>.from(data);
  }
}
