import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calc/calculator_models.dart';
import '../calc/transaction_calculator.dart';
import '../models/create_transaction_request.dart';
import '../models/discount_item.dart';
import '../models/payment_setting.dart';
import '../models/promotion_item.dart';
import '../util/calc_mappers.dart';
import 'cart_controller.dart';
import 'pos_providers.dart';

/// The checkout calculation and the choices that produced it.
class CheckoutState {
  const CheckoutState({
    required this.result,
    this.discount,
    this.promotions = const [],
    this.savings = const PerItemSavingsResult(savings: {}, labels: {}),
    this.paymentMethod = '',
  });

  final TransactionCalculationResult result;
  final DiscountInput? discount;
  final List<PromotionInput> promotions;
  final PerItemSavingsResult savings;
  final String paymentMethod;
}

/// Calculates checkout totals once per distinct set of pricing inputs.
class CheckoutController extends Notifier<CheckoutState> {
  DiscountItem? _discountItem;
  String _paymentMethod = '';
  Map<int, Map<String, int>> _selectedRewards = const {};
  _CalcFingerprint? _lastFingerprint;
  CheckoutState? _cachedState;

  @override
  CheckoutState build() {
    final lines = ref.watch(
      cartControllerProvider.select((cart) => cart.lines),
    );
    final paymentSetting = ref.watch(
      paymentSettingProvider.select((value) => value.valueOrNull),
    );
    final promotionItems = ref.watch(
      activePromotionsProvider.select((value) => value.valueOrNull ?? const []),
    );
    return _calculate(lines, paymentSetting, promotionItems);
  }

  void applyDiscount(DiscountItem? discount) {
    _discountItem = discount;
    _refresh();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    _refresh();
  }

  void selectReward(int promotionId, Map<String, int> qtyByCartKey) {
    final updated = <int, Map<String, int>>{
      ..._selectedRewards,
      promotionId: Map.unmodifiable(qtyByCartKey),
    };
    _selectedRewards = Map.unmodifiable(updated);
    _refresh();
  }

  CreateTransactionRequest buildPayload({
    required String cashTendered,
    required String cashChange,
    int? queueNumber,
    String? notes,
  }) {
    final lines = ref.read(cartControllerProvider).lines;
    final paymentSetting = ref.read(paymentSettingProvider).valueOrNull;
    final cartItems = lines.values.map(toCartItemData).toList(growable: false);
    return TransactionCalculator.buildTransactionPayload(
      result: state.result,
      paymentMethod: state.paymentMethod,
      cashTendered: cashTendered,
      cashChange: cashChange,
      queueNumber: queueNumber,
      notes: notes,
      priceIncludeTax: paymentSetting?.isPriceIncludeTax ?? false,
      discountId: state.discount?.discountId,
      promotionIds: state.result.appliedPromotionIds,
      paymentSettings: paymentSetting,
      discountInput: state.discount,
      appliedPromotions: state.promotions,
      cartItemsForBreakdown: cartItems,
    );
  }

  void _refresh() {
    state = _calculate(
      ref.read(cartControllerProvider).lines,
      ref.read(paymentSettingProvider).valueOrNull,
      ref.read(activePromotionsProvider).valueOrNull ?? const [],
    );
  }

  CheckoutState _calculate(
    Map<String, PosCartLine> lines,
    PaymentSetting? paymentSetting,
    List<PromotionItem> promotionItems,
  ) {
    final cartItems = lines.values.map(toCartItemData).toList(growable: false);
    final promotions = toPromotionInputs(
      promotionItems,
      selectedRewards: _selectedRewards,
    );
    final discount = _discountItem == null
        ? null
        : toDiscountInput(_discountItem!);
    final fingerprint = _CalcFingerprint(
      cartItems: cartItems,
      discountId: discount?.discountId,
      promotionIds: promotions.map((item) => item.promotionId).toList(),
      selectedRewards: _selectedRewards,
      paymentSettingId: paymentSetting?.paymentSettingId,
      paymentMethod: _paymentMethod,
    );
    if (fingerprint == _lastFingerprint && _cachedState != null) {
      return _cachedState!;
    }

    final result = TransactionCalculator.calculateTransaction(
      TransactionCalculationInput(
        cartItems: cartItems,
        paymentSettings: paymentSetting,
        paymentMethod: _paymentMethod,
        priceIncludeTax: paymentSetting?.isPriceIncludeTax ?? false,
        discountInput: discount,
        promotions: promotions,
      ),
    );
    final next = CheckoutState(
      result: result,
      discount: discount,
      promotions: promotions,
      savings: TransactionCalculator.computePerItemSavings(
        cartItems,
        discount,
        promotions,
      ),
      paymentMethod: _paymentMethod,
    );
    _lastFingerprint = fingerprint;
    _cachedState = next;
    return next;
  }
}

class _CalcFingerprint {
  const _CalcFingerprint({
    required this.cartItems,
    required this.discountId,
    required this.promotionIds,
    required this.selectedRewards,
    required this.paymentSettingId,
    required this.paymentMethod,
  });

  final List<CartItemData> cartItems;
  final int? discountId;
  final List<int> promotionIds;
  final Map<int, Map<String, int>> selectedRewards;
  final int? paymentSettingId;
  final String paymentMethod;

  static const _deepEquality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CalcFingerprint &&
          _deepEquality.equals(other.cartItems, cartItems) &&
          other.discountId == discountId &&
          _deepEquality.equals(other.promotionIds, promotionIds) &&
          _deepEquality.equals(other.selectedRewards, selectedRewards) &&
          other.paymentSettingId == paymentSettingId &&
          other.paymentMethod == paymentMethod;

  @override
  int get hashCode => Object.hash(
    _deepEquality.hash(cartItems),
    discountId,
    _deepEquality.hash(promotionIds),
    _deepEquality.hash(selectedRewards),
    paymentSettingId,
    paymentMethod,
  );
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);

final checkoutTotalsProvider = Provider<TransactionCalculationResult>(
  (ref) => ref.watch(
    checkoutControllerProvider.select((checkout) => checkout.result),
  ),
);

final lineSavingsProvider = Provider.family<double, String>(
  (ref, cartKey) => ref.watch(
    checkoutControllerProvider.select(
      (checkout) => checkout.savings.savings[cartKey] ?? 0,
    ),
  ),
);
