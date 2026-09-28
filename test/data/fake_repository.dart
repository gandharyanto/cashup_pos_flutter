import 'package:cashup_pos/src/data/pos_repository.dart';
import 'package:cashup_pos/src/models/create_transaction_request.dart';
import 'package:cashup_pos/src/models/discount_item.dart';
import 'package:cashup_pos/src/models/option_group.dart';
import 'package:cashup_pos/src/models/paged_result.dart';
import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:cashup_pos/src/models/pos_area.dart';
import 'package:cashup_pos/src/models/pos_category.dart';
import 'package:cashup_pos/src/models/pos_lookup_page.dart';
import 'package:cashup_pos/src/models/pos_merchant_summary.dart';
import 'package:cashup_pos/src/models/pos_payment_method.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/models/promotion_item.dart';
import 'package:cashup_pos/src/models/stock_movement.dart';
import 'package:cashup_pos/src/models/summary_report.dart';
import 'package:cashup_pos/src/models/transaction_details.dart';
import 'package:cashup_pos/src/models/transaction_summary.dart';

/// Builds a minimal [PosProduct] for state-layer tests, materialising
/// [categories] into [PosCategory] entries so [PosProduct.categoryIds]
/// (which the catalogue filter reads) works.
PosProduct product(int id, String name, {List<int> categories = const []}) {
  return PosProduct(
    id: id,
    name: name,
    sku: 'SKU$id',
    categories: categories
        .map(
          (categoryId) => PosCategory(id: categoryId, name: 'Cat$categoryId'),
        )
        .toList(growable: false),
  );
}

/// In-memory [PosRepository] for state-layer tests.
///
/// [productList] and [categoryList] return the settable [products] /
/// [categories] lists and count how many times each was called — the only
/// behaviour `CatalogController`'s tests need. [productOptionGroups] is a
/// similarly simple settable lookup, since `CatalogController.optionGroups`
/// delegates straight to it. Every other method throws
/// [UnimplementedError]; later state tasks extend this file with real
/// behaviour as they need it, rather than fighting this one.
class FakeRepository implements PosRepository {
  List<PosProduct> products = const [];
  List<PosCategory> categories = const [];
  Map<int, ProductOptionGroups?> optionGroupsByProduct = const {};

  int productListCalls = 0;
  int categoryListCalls = 0;
  int productOptionGroupsCalls = 0;

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
    productListCalls++;
    return PagedResult<PosProduct>.single(products);
  }

  @override
  Future<PagedResult<PosCategory>> categoryList({int size = 100}) async {
    categoryListCalls++;
    return PagedResult<PosCategory>.single(categories);
  }

  @override
  Future<ProductOptionGroups?> productOptionGroups(int productId) async {
    productOptionGroupsCalls++;
    return optionGroupsByProduct[productId];
  }

  @override
  Future<PosProduct> productDetail(int productId) => throw UnimplementedError();

  @override
  Future<int> productCreate(PosProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> productUpdate(int productId, PosProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> productDelete(int productId) => throw UnimplementedError();

  @override
  Future<PosCategory> categoryDetail(int categoryId) =>
      throw UnimplementedError();

  @override
  Future<int> categoryCreate(PosCategoryDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> categoryUpdate(int categoryId, PosCategoryDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> categoryDelete(int categoryId) => throw UnimplementedError();

  @override
  Future<void> stockUpdate({
    required int productId,
    required int qty,
    required String updateType,
  }) => throw UnimplementedError();

  @override
  Future<PagedResult<StockMovementRow>> stockMovements({
    required int productId,
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  @override
  Future<PaymentSetting?> paymentSetting() => throw UnimplementedError();

  @override
  Future<void> paymentSettingCreate(PaymentSetting setting) =>
      throw UnimplementedError();

  @override
  Future<void> paymentSettingUpdate(PaymentSetting setting) =>
      throw UnimplementedError();

  @override
  Future<List<PosPaymentMethod>> paymentMethods() => throw UnimplementedError();

  @override
  Future<CreatedTransaction> transactionCreate(
    CreateTransactionRequest request,
  ) => throw UnimplementedError();

  @override
  Future<TransactionDetails> transactionDetail(int transactionId) =>
      throw UnimplementedError();

  @override
  Future<void> transactionUpdate(
    String merchantTrxId,
    UpdateTransactionRequest request,
  ) => throw UnimplementedError();

  @override
  Future<PagedResult<TransactionSummaryRow>> transactionList({
    required int page,
    required int size,
    required DateTime startDate,
    required DateTime endDate,
    String sortBy = 'transactionDate',
    String sortType = 'DESC',
  }) => throw UnimplementedError();

  @override
  Future<SummaryReportData> summaryReport({
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  @override
  Future<List<DiscountItem>> discountList() => throw UnimplementedError();

  @override
  Future<List<PromotionItem>> activePromotions() => throw UnimplementedError();

  @override
  Future<PosLookupPage<PosArea>> areaList({int size = 100, String? keyword}) =>
      throw UnimplementedError();

  @override
  Future<PosLookupPage<PosMerchantSummary>> merchantList({
    int size = 100,
    String? keyword,
  }) => throw UnimplementedError();

  @override
  Future<PosLookupPage<PosMerchantSummary>> merchantsByArea({
    required int areaId,
    int size = 100,
    String? keyword,
  }) => throw UnimplementedError();
}
