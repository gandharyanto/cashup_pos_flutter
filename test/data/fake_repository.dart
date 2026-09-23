import 'package:cashup_pos/src/data/pos_repository.dart';
import 'package:cashup_pos/src/models/create_transaction_request.dart';
import 'package:cashup_pos/src/models/discount_item.dart';
import 'package:cashup_pos/src/models/option_group.dart';
import 'package:cashup_pos/src/models/paged_result.dart';
import 'package:cashup_pos/src/models/payment_setting.dart';
import 'package:cashup_pos/src/models/pos_category.dart';
import 'package:cashup_pos/src/models/pos_payment_method.dart';
import 'package:cashup_pos/src/models/pos_product.dart';
import 'package:cashup_pos/src/models/promotion_item.dart';
import 'package:cashup_pos/src/models/stock_movement.dart';
import 'package:cashup_pos/src/models/summary_report.dart';
import 'package:cashup_pos/src/models/transaction_details.dart';
import 'package:cashup_pos/src/models/transaction_summary.dart';

/// Builds a [PosProduct] for tests, with [categories] expanded into bare
/// [PosCategory] stand-ins so `PosProduct.categoryIds` works without a real
/// category fetch.
PosProduct product(
  int id,
  String name, {
  String? sku,
  List<int> categories = const [],
}) => PosProduct(
  id: id,
  name: name,
  sku: sku,
  categories: categories
      .map((categoryId) => category(categoryId, 'Category $categoryId'))
      .toList(growable: false),
);

/// Builds a [PosCategory] for tests.
PosCategory category(int id, String name) => PosCategory(id: id, name: name);

/// An in-memory [PosRepository] test double.
///
/// Every method increments a per-method call counter (`xCalls`) so a test
/// can assert a controller does or doesn't hit the network again, and every
/// list-shaped method returns a settable `xResult` field the test can
/// populate up front. Reusable across the state-layer tasks (cart, checkout,
/// transactions, admin) that build on [PosRepository] — every method is
/// implemented, even the ones `catalog_controller_test.dart` doesn't
/// exercise.
class FakeRepository implements PosRepository {
  List<PosProduct> products = const [];
  List<PosCategory> categories = const [];
  ProductOptionGroups? optionGroupsResult;
  PaymentSetting? paymentSettingResult;
  List<PosPaymentMethod> paymentMethodsResult = const [];
  List<StockMovementRow> stockMovementsResult = const [];
  CreatedTransaction transactionCreateResult = const CreatedTransaction(
    id: 0,
    trxId: '',
  );
  TransactionDetails? transactionDetailResult;
  List<TransactionSummaryRow> transactionListResult = const [];
  SummaryReportData summaryReportResult = const SummaryReportData();
  List<DiscountItem> discountListResult = const [];
  List<PromotionItem> activePromotionsResult = const [];
  int nextCreatedId = 1;

  int productListCalls = 0;
  int productDetailCalls = 0;
  int productCreateCalls = 0;
  int productUpdateCalls = 0;
  int productDeleteCalls = 0;
  int productOptionGroupsCalls = 0;
  int categoryListCalls = 0;
  int categoryDetailCalls = 0;
  int categoryCreateCalls = 0;
  int categoryUpdateCalls = 0;
  int categoryDeleteCalls = 0;
  int stockUpdateCalls = 0;
  int stockMovementsCalls = 0;
  int paymentSettingCalls = 0;
  int paymentSettingCreateCalls = 0;
  int paymentSettingUpdateCalls = 0;
  int paymentMethodsCalls = 0;
  int transactionCreateCalls = 0;
  int transactionDetailCalls = 0;
  int transactionUpdateCalls = 0;
  int transactionListCalls = 0;
  int summaryReportCalls = 0;
  int discountListCalls = 0;
  int activePromotionsCalls = 0;

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
    return PagedResult.single(products);
  }

  @override
  Future<PosProduct> productDetail(int productId) async {
    productDetailCalls++;
    return products.firstWhere((p) => p.id == productId);
  }

  @override
  Future<int> productCreate(PosProductDraft draft) async {
    productCreateCalls++;
    return nextCreatedId++;
  }

  @override
  Future<void> productUpdate(int productId, PosProductDraft draft) async {
    productUpdateCalls++;
  }

  @override
  Future<void> productDelete(int productId) async {
    productDeleteCalls++;
  }

  @override
  Future<ProductOptionGroups?> productOptionGroups(int productId) async {
    productOptionGroupsCalls++;
    return optionGroupsResult;
  }

  @override
  Future<PagedResult<PosCategory>> categoryList({int size = 100}) async {
    categoryListCalls++;
    return PagedResult.single(categories);
  }

  @override
  Future<PosCategory> categoryDetail(int categoryId) async {
    categoryDetailCalls++;
    return categories.firstWhere((c) => c.id == categoryId);
  }

  @override
  Future<int> categoryCreate(PosCategoryDraft draft) async {
    categoryCreateCalls++;
    return nextCreatedId++;
  }

  @override
  Future<void> categoryUpdate(int categoryId, PosCategoryDraft draft) async {
    categoryUpdateCalls++;
  }

  @override
  Future<void> categoryDelete(int categoryId) async {
    categoryDeleteCalls++;
  }

  @override
  Future<void> stockUpdate({
    required int productId,
    required int qty,
    required String updateType,
  }) async {
    stockUpdateCalls++;
  }

  @override
  Future<PagedResult<StockMovementRow>> stockMovements({
    required int productId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    stockMovementsCalls++;
    return PagedResult.single(stockMovementsResult);
  }

  @override
  Future<PaymentSetting?> paymentSetting() async {
    paymentSettingCalls++;
    return paymentSettingResult;
  }

  @override
  Future<void> paymentSettingCreate(PaymentSetting setting) async {
    paymentSettingCreateCalls++;
    paymentSettingResult = setting;
  }

  @override
  Future<void> paymentSettingUpdate(PaymentSetting setting) async {
    paymentSettingUpdateCalls++;
    paymentSettingResult = setting;
  }

  @override
  Future<List<PosPaymentMethod>> paymentMethods() async {
    paymentMethodsCalls++;
    return paymentMethodsResult;
  }

  @override
  Future<CreatedTransaction> transactionCreate(
    CreateTransactionRequest request,
  ) async {
    transactionCreateCalls++;
    return transactionCreateResult;
  }

  @override
  Future<TransactionDetails> transactionDetail(int transactionId) async {
    transactionDetailCalls++;
    return transactionDetailResult ??
        TransactionDetails(
          transactionId: transactionId,
          code: '',
          status: '',
          paymentMethod: '',
          transactionDate: '',
        );
  }

  @override
  Future<void> transactionUpdate(
    String merchantTrxId,
    UpdateTransactionRequest request,
  ) async {
    transactionUpdateCalls++;
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
    transactionListCalls++;
    return PagedResult.single(transactionListResult);
  }

  @override
  Future<SummaryReportData> summaryReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    summaryReportCalls++;
    return summaryReportResult;
  }

  @override
  Future<List<DiscountItem>> discountList() async {
    discountListCalls++;
    return discountListResult;
  }

  @override
  Future<List<PromotionItem>> activePromotions() async {
    activePromotionsCalls++;
    return activePromotionsResult;
  }
}
