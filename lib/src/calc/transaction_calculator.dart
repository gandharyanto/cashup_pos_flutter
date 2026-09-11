import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../models/create_transaction_request.dart';
import '../models/option_group.dart';
import '../models/payment_setting.dart';
import '../models/transaction_details.dart';
import '../util/num_utils.dart';
import '../util/pos_date_utils.dart';
import 'calculator_models.dart';
import 'promotion/buyxgety/buy_x_get_y_evaluator.dart';
import 'promotion/evaluation_context.dart';
import 'promotion/promotion_evaluator.dart';
import 'promotion/promotion_orchestrator.dart';
import 'rounding_utils.dart';

/// Prices a transaction.
///
/// Ported from `TransactionCalculator.kt`. The backend re-computes every amount
/// this produces and rejects the transaction on mismatch, so the order of
/// operations and each rounding step are load-bearing:
///
/// 1. `subTotal = Σ effectivePrice × qty`
/// 2. a preliminary discount, used as context for promotion evaluation
/// 3. promotions, via [PromotionOrchestrator]
/// 4. free quantities from any applied FREE `BUY_X_GET_Y`
/// 5. the final discount, now aware of which units are free
/// 6. promotion capped at what is left after the discount
/// 7. per-item deductions, then tax on the reduced base
/// 8. service charge on `subTotal + tax`, *before* discount
/// 9. cash rounding — payment settings first, then whole rupiah
///
/// Every amount is a `double`; see `num_utils.dart` for how JVM rounding is
/// reproduced.
class TransactionCalculator {
  TransactionCalculator._();

  static const _orchestrator = PromotionOrchestrator();
  static const _buyXGetY = BuyXGetYEvaluator();

  /// How many times [calculateTransaction] has run.
  ///
  /// Exists so the checkout controller's memoisation test can assert the
  /// calculation is not repeated on a rebuild. It is the most expensive
  /// function in the SDK, and the performance budget depends on it running
  /// only when its inputs change.
  static int debugCalculationCount = 0;

  /// Prices [input] and builds the transaction lines that go with it.
  static TransactionCalculationResult calculateTransaction(
    TransactionCalculationInput input,
  ) {
    debugCalculationCount++;

    final cartItems = input.cartItems;
    final isCashPayment = input.isCashPayment;
    final subTotal = cartItems.fold<double>(
      0,
      (sum, i) => sum + i.lineSubtotal,
    );

    // Phase 1 — a discount that does not yet know about free units. It seeds
    // the promotion context and the per-line map FreeRewardStrategy reads.
    final discount = input.discountInput;
    final prelimDiscountAmt = discount == null
        ? 0.0
        : _calculateDiscountAmount(discount, cartItems, subTotal, const {});
    final discountPerCartKey = _buildDiscountPerCartKey(
      discount,
      cartItems,
      prelimDiscountAmt,
    );

    // Phase 2 — promotions.
    final baseCtx = EvaluationContext(
      cartItems: cartItems,
      originalCartItems: cartItems,
      discountInput: discount,
      totalDiscountAmt: prelimDiscountAmt,
      subTotal: subTotal,
      freeItemCartKeys: const {},
      freeQtyByCartKey: const {},
      discountPerCartKey: discountPerCartKey,
    );
    final promoOutcome = _orchestrator.evaluateAll(input.promotions, baseCtx);

    final appliedFreePromos = input.promotions
        .where(
          (p) =>
              promoOutcome.appliedIds.contains(p.promotionId) &&
              p.isBuyXGetY &&
              p.isFreeReward,
        )
        .toList(growable: false);
    final freeQtyByCartKey = _computeFreeQtyByCartKey(
      appliedFreePromos,
      cartItems,
      discount,
      prelimDiscountAmt,
      subTotal,
      discountPerCartKey,
    );
    final freeItemCartKeys = _fullyFreeCartKeys(freeQtyByCartKey, cartItems);

    // Phase 3 — the final discount, aware of free units.
    final discountAmount = discount == null
        ? 0.0
        : _calculateDiscountAmount(
            discount,
            cartItems,
            subTotal,
            freeQtyByCartKey,
          );

    // A promotion can never take more than the order has left, or netAmount
    // would go negative.
    final effectivePromotionAmount = math.min(
      promoOutcome.totalAmount,
      atLeastZero(subTotal - discountAmount),
    );
    final totalDeduction = discountAmount + effectivePromotionAmount;

    // taxAppliedAfterDiscount is always true: every item's taxable base drops
    // by its full share of the discount and the promotions.
    final perItemDeductionsForTax = _computePerItemTotalDeductionByCartKey(
      promotions: input.promotions,
      appliedPromoIds: promoOutcome.appliedIds,
      cartItems: cartItems,
      freeItemCartKeys: freeItemCartKeys,
      freeQtyByCartKey: freeQtyByCartKey,
      discountInput: discount,
      totalDiscountAmt: discountAmount,
      subTotal: subTotal,
      discountPerCartKey: discountPerCartKey,
      perPromoAmounts: promoOutcome.perPromoAmounts,
    );

    var tax = setScale(
      cartItems
          .where((i) => i.isTaxable && !freeItemCartKeys.contains(i.cartKey))
          .fold<double>(
            0,
            (sum, i) =>
                sum +
                _calculateItemTaxAmount(
                  i,
                  input.priceIncludeTax,
                  perItemDeductionsForTax[i.cartKey] ?? 0,
                ),
          ),
      2,
    );

    final taxBreakdowns = _buildTaxBreakdowns(
      cartItems,
      freeItemCartKeys,
      input.priceIncludeTax,
      perItemDeductionsForTax,
    );

    // Service charge is applied to (subTotal + tax), before the discount.
    var serviceCharge = 0.0;
    final settings = input.paymentSettings;
    if (settings != null && settings.isServiceCharge) {
      serviceCharge =
          settings.serviceChargeAmount +
          (subTotal + tax) * settings.serviceChargePercentage / 100;
    }

    // With priceIncludeTax the tax is already inside subTotal — adding it again
    // would double-count it.
    var totalAmount = input.priceIncludeTax
        ? subTotal - totalDeduction + serviceCharge
        : subTotal - totalDeduction + tax + serviceCharge;
    var rounding = 0.0;

    // The merchant's rounding rule applies to cash only.
    if (isCashPayment && settings != null && settings.isRounding) {
      final originalTotal = totalAmount;
      final roundedTotal = RoundingUtils.applyRounding(
        amount: totalAmount,
        target: settings.roundingTarget,
        type: settings.roundingType,
      );
      rounding = RoundingUtils.calculateRoundingAdjustment(
        originalTotal,
        roundedTotal,
      );
      totalAmount = roundedTotal;
    }

    // Cash additionally settles to whole rupiah, and the rounding line is
    // recomputed against the unrounded base so the receipt reconciles.
    if (isCashPayment) {
      final base = input.priceIncludeTax
          ? subTotal - totalDeduction + serviceCharge
          : subTotal - totalDeduction + serviceCharge + tax;
      final roundedTotalAmount = roundToIntegerForCash(totalAmount);

      serviceCharge = roundToIntegerForCash(serviceCharge);
      tax = roundToIntegerForCash(tax);
      rounding = roundedTotalAmount - base;
      totalAmount = roundedTotalAmount;
    }

    final transactionItems = cartItems
        .map(
          (item) => _buildPlainTransactionItem(
            item,
            input.priceIncludeTax,
            freeItemCartKeys.contains(item.cartKey)
                ? 0
                : _calculateItemTaxAmount(
                    item,
                    input.priceIncludeTax,
                    perItemDeductionsForTax[item.cartKey] ?? 0,
                  ),
          ),
        )
        .toList(growable: false);

    return TransactionCalculationResult(
      subTotal: subTotal,
      discountAmount: discountAmount,
      promotionAmount: effectivePromotionAmount,
      serviceCharge: serviceCharge,
      tax: tax,
      rounding: rounding,
      totalAmount: totalAmount,
      transactionItems: transactionItems,
      taxBreakdowns: taxBreakdowns,
      appliedPromotionIds: promoOutcome.appliedIds,
      perPromoAmounts: promoOutcome.perPromoAmounts,
    );
  }

  /// The cash total and the rounding it introduced, for the cash dialog.
  ///
  /// Applies the merchant's rounding rule and then settles to whole rupiah.
  static ({double total, double rounding}) calculateCashPaymentWithRounding(
    double originalTotal,
    PaymentSetting? paymentSettings,
  ) {
    var totalAmount = originalTotal;

    if (paymentSettings != null && paymentSettings.isRounding) {
      totalAmount = RoundingUtils.applyRounding(
        amount: totalAmount,
        target: paymentSettings.roundingTarget,
        type: paymentSettings.roundingType,
      );
    }

    final roundedTotalAmount = roundToIntegerForCash(totalAmount);
    return (
      total: roundedTotalAmount,
      rounding: roundedTotalAmount - originalTotal,
    );
  }

  /// The total to show on screen.
  ///
  /// Cash totals are already whole. Other methods are rounded for display so a
  /// fractional tax does not surface as `Rp 19.860,50`.
  static double getRoundedTotalAmountForDisplay(
    TransactionCalculationResult result, {
    String paymentMethod = '',
  }) => paymentMethod.toUpperCase() == 'CASH'
      ? result.totalAmount
      : jvmRound(result.totalAmount);

  // ─── Payload ──────────────────────────────────────────────────────────────

  /// The `pos/transaction/create` payload for a priced [result].
  ///
  /// With [cartItemsForBreakdown] — the cart [result] was priced from — every
  /// line carries its `discounts`, `promotions` and `taxes` arrays. Without it
  /// the result's plain lines are sent as they are.
  ///
  /// [priceIncludeTax] selects the totals formula and is reported in
  /// `paymentSetting` only when [paymentSettings] is null; the merchant's own
  /// setting wins there.
  static CreateTransactionRequest buildTransactionPayload({
    required TransactionCalculationResult result,
    required String paymentMethod,
    String cashTendered = '0',
    String cashChange = '0',
    int? queueNumber,
    bool priceIncludeTax = false,
    String? notes,
    int? discountId,
    List<int>? promotionIds,
    PaymentSetting? paymentSettings,
    DiscountInput? discountInput,
    List<PromotionInput> appliedPromotions = const [],
    List<CartItemData> cartItemsForBreakdown = const [],
  }) {
    final promoIds = promotionIds != null && promotionIds.isNotEmpty
        ? promotionIds
        : (result.appliedPromotionIds.isNotEmpty
              ? result.appliedPromotionIds
              : null);

    final promotionAmountForPayload = result.promotionAmount;
    final discountAmountStr = result.discountAmount > 0
        ? formatDecimalFixed2(result.discountAmount)
        : null;
    final promotionAmountStr = promotionAmountForPayload > 0
        ? formatDecimalFixed2(promotionAmountForPayload)
        : null;

    // grossAmount − totalDiscount − totalPromotion. Tax is not deducted.
    final netAmount =
        result.subTotal - result.discountAmount - promotionAmountForPayload;

    final paymentSettingRequest = _buildPaymentSettingRequest(
      paymentSettings,
      priceIncludeTax,
    );

    final List<RequestTransactionItem> items;
    if (cartItemsForBreakdown.isNotEmpty) {
      // Re-derived against the *final* discount, not the preliminary one
      // calculateTransaction seeded promotions with — Kotlin does the same.
      final payloadFreePromos = appliedPromotions
          .where(
            (p) =>
                result.appliedPromotionIds.contains(p.promotionId) &&
                p.isBuyXGetY &&
                p.isFreeReward,
          )
          .toList(growable: false);
      final payloadDiscountPerCartKey = _buildDiscountPerCartKey(
        discountInput,
        cartItemsForBreakdown,
        result.discountAmount,
      );
      final payloadFreeQtyByCartKey = _computeFreeQtyByCartKey(
        payloadFreePromos,
        cartItemsForBreakdown,
        discountInput,
        result.discountAmount,
        result.subTotal,
        payloadDiscountPerCartKey,
      );
      final payloadFreeKeys = _fullyFreeCartKeys(
        payloadFreeQtyByCartKey,
        cartItemsForBreakdown,
      );
      final payloadPerItemPromoAmounts = _computePerItemTotalDeductionByCartKey(
        promotions: appliedPromotions,
        appliedPromoIds: result.appliedPromotionIds,
        cartItems: cartItemsForBreakdown,
        freeItemCartKeys: payloadFreeKeys,
        freeQtyByCartKey: payloadFreeQtyByCartKey,
        discountInput: discountInput,
        totalDiscountAmt: result.discountAmount,
        subTotal: result.subTotal,
        discountPerCartKey: payloadDiscountPerCartKey,
        perPromoAmounts: result.perPromoAmounts,
      );
      items = _buildItemsWithBreakdown(
        cartItems: cartItemsForBreakdown,
        discountInput: discountInput,
        totalDiscountAmt: result.discountAmount,
        appliedPromotions: appliedPromotions,
        appliedPromoIds: result.appliedPromotionIds,
        subTotal: result.subTotal,
        priceIncludeTax: priceIncludeTax,
        freeItemCartKeys: payloadFreeKeys,
        freeQtyByCartKey: payloadFreeQtyByCartKey,
        perItemPromoAmounts: payloadPerItemPromoAmounts,
        discountPerCartKey: payloadDiscountPerCartKey,
        perPromoAmounts: result.perPromoAmounts,
      );
    } else {
      items = result.transactionItems;
    }

    // Ascending by first discount amount. Kotlin's sortedBy is stable, so lines
    // with equal amounts keep cart order; List.sort would not.
    final transactionItemsWithBreakdown = List<RequestTransactionItem>.of(
      items,
      growable: false,
    );
    mergeSort<RequestTransactionItem>(
      transactionItemsWithBreakdown,
      compare: (a, b) => a.firstDiscountAmount.compareTo(b.firstDiscountAmount),
    );

    // The aggregate tax, never the sum of the per-line rows: rounding each
    // line to 2 dp diverges from the server's aggregate computation.
    final derivedTotalTax = result.tax;

    final String totalAmount;
    if (priceIncludeTax) {
      totalAmount = formatDecimalFixed2(
        result.subTotal -
            result.discountAmount -
            promotionAmountForPayload +
            result.serviceCharge,
      );
    } else if (paymentMethod.toUpperCase() == 'CASH') {
      // Already settled to whole rupiah by calculateTransaction.
      totalAmount = formatDecimalFixed2(result.totalAmount);
    } else {
      // Rebuilt from whole-rupiah components, so a fractional tax cannot
      // leave a non-cash total at .50.
      final totalDeduction = result.discountAmount + promotionAmountForPayload;
      totalAmount = formatDecimalFixed2(
        jvmRound(result.subTotal) -
            totalDeduction +
            jvmRound(result.serviceCharge) +
            jvmRound(result.rounding) +
            jvmRound(derivedTotalTax),
      );
    }

    return CreateTransactionRequest(
      paymentMethod: paymentMethod,
      subTotal: formatDecimalFixed2(result.subTotal),
      netAmount: formatDecimalFixed2(netAmount),
      discountAmount: discountAmountStr,
      promotionAmount: promotionAmountStr,
      totalServiceCharge: formatDecimalFixed2(result.serviceCharge),
      totalTax: formatDecimalFixed2(derivedTotalTax),
      totalRounding: formatDecimalFixed2(result.rounding),
      totalAmount: totalAmount,
      paymentSetting: paymentSettingRequest,
      discountId: discountId,
      promotionIds: promoIds,
      cashTendered: cashTendered,
      cashChange: cashChange,
      transactionItems: transactionItemsWithBreakdown,
      queueNumber: queueNumber,
      notes: notes != null && notes.trim().isNotEmpty ? notes : null,
    );
  }

  /// The `paymentSetting` block. Always emitted, even with no settings, so the
  /// backend is always told `taxAppliedAfterDiscount`.
  static PaymentSettingRequest _buildPaymentSettingRequest(
    PaymentSetting? settings,
    bool priceIncludeTax,
  ) {
    ServiceChargeRequest? serviceChargeRequest;
    if (settings != null && settings.isServiceCharge) {
      final pct = settings.serviceChargePercentage;
      final amt = settings.serviceChargeAmount;
      if (pct > 0) {
        serviceChargeRequest = ServiceChargeRequest(
          type: 'PERCENTAGE',
          value: pct,
        );
      } else if (amt > 0) {
        serviceChargeRequest = ServiceChargeRequest(type: 'AMOUNT', value: amt);
      }
    }

    return PaymentSettingRequest(
      priceIncludeTax: settings?.isPriceIncludeTax ?? priceIncludeTax,
      serviceCharge: serviceChargeRequest,
    );
  }

  /// Payload lines with their per-item `discounts`, `promotions` and `taxes`.
  ///
  /// Kotlin also takes the result's existing lines here but never reads them,
  /// so the parameter is not ported.
  static List<RequestTransactionItem> _buildItemsWithBreakdown({
    required List<CartItemData> cartItems,
    required DiscountInput? discountInput,
    required double totalDiscountAmt,
    required List<PromotionInput> appliedPromotions,
    required List<int> appliedPromoIds,
    required double subTotal,
    required bool priceIncludeTax,
    required Set<String> freeItemCartKeys,
    required Map<String, int> freeQtyByCartKey,
    required Map<String, double> perItemPromoAmounts,
    required Map<String, double> discountPerCartKey,
    required Map<int, double> perPromoAmounts,
  }) {
    // Identical for every line; Kotlin rebuilds it per line.
    final roleCtx = EvaluationContext(
      cartItems: cartItems,
      originalCartItems: cartItems,
      discountInput: discountInput,
      totalDiscountAmt: totalDiscountAmt,
      subTotal: subTotal,
      freeItemCartKeys: freeItemCartKeys,
      freeQtyByCartKey: freeQtyByCartKey,
      discountPerCartKey: discountPerCartKey,
    );

    return cartItems
        .map((item) {
          // A PERCENTAGE row is computed per line on the FULL quantity, so it
          // matches the server's round(price × qty × pct / 100) exactly — the
          // server validates it independently of free units. Kotlin applies
          // no cap to this row either, and neither does the port.
          final double itemDiscountAmt;
          if (discountInput != null &&
              discountInput.valueType == DiscountInput.typePercentage) {
            final eligible = switch (discountInput.scope) {
              DiscountInput.scopeAll => true,
              DiscountInput.scopeProduct =>
                discountInput.eligibleProductIds.contains(item.productId),
              DiscountInput.scopeCategory => item.categoryIds.any(
                discountInput.eligibleCategoryIds.contains,
              ),
              _ => false,
            };
            itemDiscountAmt = eligible
                ? _itemDiscountRounded(item, discountInput.value)
                : 0;
          } else {
            itemDiscountAmt = _computeItemDiscountAmt(
              item,
              discountInput,
              totalDiscountAmt,
              cartItems,
              freeItemCartKeys: freeItemCartKeys,
            );
          }
          final discountDetails = discountInput != null && itemDiscountAmt > 0
              ? [
                  ItemDiscountDetail(
                    id: discountInput.discountId ?? 0,
                    type: discountInput.valueType,
                    value: discountInput.value,
                    amt: formatDecimalFixed2(itemDiscountAmt),
                  ),
                ]
              : null;

          final promoRoles = _orchestrator.computeAllItemRoles(
            item,
            appliedPromotions,
            appliedPromoIds,
            roleCtx,
            perPromoAmounts,
          );
          final promotionDetails = promoRoles.isEmpty
              ? null
              : promoRoles
                    .map(
                      (role) => ItemPromotionDetail(
                        id: role.promotionId,
                        type: role.promoType,
                        amt: formatDecimalFixed2(role.amt),
                        meta: ItemPromotionMeta(
                          role: role.role,
                          buyQty: role.buyQty,
                          getQty: role.getQty,
                        ),
                      ),
                    )
                    .toList(growable: false);

          // taxAppliedAfterDiscount is always true. The server validates
          // Σ (totalPrice − deduction) × rate — or × rate/(1+rate) with
          // priceIncludeTax — against the *raw* discount share, so the share
          // is recomputed unrounded rather than reusing the row above.
          final taxDiscountShare = _computeItemDiscountAmt(
            item,
            discountInput,
            totalDiscountAmt,
            cartItems,
            freeItemCartKeys: freeItemCartKeys,
            roundAmountDiscount: false,
          );
          final promoOnlyDeduction = atLeastZero(
            (perItemPromoAmounts[item.cartKey] ?? 0) - taxDiscountShare,
          );
          final taxDeduction = taxDiscountShare + promoOnlyDeduction;
          final itemTaxAmt = freeItemCartKeys.contains(item.cartKey)
              ? 0.0
              : _calculateItemTaxAmount(item, priceIncludeTax, taxDeduction);
          final taxId = item.taxId;
          final taxDetails = item.isTaxable && itemTaxAmt > 0 && taxId != null
              ? [
                  ItemTaxDetail(
                    id: taxId,
                    type: 'PERCENTAGE',
                    value: item.taxPercentage ?? 0,
                    amt: formatDecimalFixed2(itemTaxAmt),
                  ),
                ]
              : null;

          return RequestTransactionItem(
            productId: item.productId,
            productName: item.productName,
            price: formatDecimalFixed2(item.basePrice),
            qty: item.quantity,
            totalPrice: formatDecimalFixed2(item.lineSubtotal),
            variantId: item.variantId,
            variantOptionIds: buildVariantOptionIds(item.selectedVariants),
            details: buildItemDetails(
              item.selectedVariants,
              item.selectedModifiers,
            ),
            discounts: discountDetails,
            promotions: promotionDetails,
            taxes: taxDetails,
            isPriceAdjustable: item.isPriceAdjustable ? true : null,
            isPriceOverride: item.isPriceOverride ? true : null,
          );
        })
        .toList(growable: false);
  }

  // ─── Receipt ──────────────────────────────────────────────────────────────

  /// A [TransactionDetails] for the receipt, built from [result] rather than
  /// fetched, so the receipt shows exactly the figures that were sent.
  ///
  /// A settled payment row is recorded only for `QRIS` and `CDCP` with a
  /// [qrisInvoice].
  static TransactionDetails buildTransactionDetails({
    required TransactionCalculationResult result,
    required int transactionId,
    required String transactionCode,
    required String paymentMethod,
    int cashTendered = 0,
    int cashChange = 0,
    String? qrisInvoice,
    PaymentSetting? paymentSettings,
    String? notes,
  }) {
    // Kotlin stamps both dates from separate Date() calls; one clock read
    // keeps them from straddling a second.
    final now = PosDates.apiDateTime(DateTime.now());

    final payments =
        (paymentMethod == 'QRIS' || paymentMethod == 'CDCP') &&
            qrisInvoice != null
        ? [
            PaymentEntry(
              transactionId: transactionId,
              paymentMethod: paymentMethod,
              amountPaid: result.totalAmount,
              status: 'PAID',
              paymentReference: qrisInvoice,
              paymentDate: now,
            ),
          ]
        : const <PaymentEntry>[];

    final responseTransactionItems = result.transactionItems
        .map((item) {
          final itemTotalPrice = double.tryParse(item.totalPrice) ?? 0;
          return TransactionLine(
            productId: item.productId,
            productName: item.productName ?? '',
            price: double.tryParse(item.price) ?? 0,
            qty: item.qty,
            grossLineTotal: itemTotalPrice,
            totalPrice: itemTotalPrice,
            details:
                item.details
                    ?.map(
                      (d) => TransactionLineDetail(
                        detailType: d.detailType,
                        name: d.name,
                        groupName: d.groupName,
                        referenceId: d.referenceId,
                        groupReferenceId: d.groupReferenceId,
                        priceAdjustment: d.priceAdjustment,
                        qty: d.qty,
                        sortOrder: d.sortOrder,
                      ),
                    )
                    .toList(growable: false) ??
                const [],
          );
        })
        .toList(growable: false);

    final pricing = TransactionPricing(
      baseAmount: result.subTotal,
      grossAmount: result.subTotal,
      discountTotal: result.discountAmount,
      promotionTotal: result.promotionAmount,
      netAmount:
          result.subTotal - result.discountAmount - result.promotionAmount,
      serviceChargePercentage: paymentSettings?.serviceChargePercentage ?? 0,
      serviceChargeTotal: result.serviceCharge,
      taxTotal: result.tax,
      roundingType: paymentSettings?.roundingType ?? 'NONE',
      roundingTarget: paymentSettings?.roundingTarget.toString() ?? '0',
      roundingTotal: result.rounding,
      totalAmount: result.totalAmount,
    );

    return TransactionDetails(
      transactionId: transactionId,
      code: transactionCode,
      status: 'COMPLETED',
      paymentMethod: paymentMethod,
      transactionDate: now,
      notes: notes,
      pricing: pricing,
      cashTendered: cashTendered.toDouble(),
      cashChange: cashChange.toDouble(),
      transactionItems: responseTransactionItems,
      payments: payments,
    );
  }

  // ─── Discount ─────────────────────────────────────────────────────────────

  /// The discount total, computed on effective prices with no tax involved.
  ///
  /// `PERCENTAGE` is computed per line and each line is rounded to whole rupiah
  /// before summing — the backend does the same, and an aggregate round
  /// diverges (121 062 × 25 % = 30 265.5 against the server's 30 266).
  ///
  /// [freeQtyByCartKey] carries units already free from a `BUY_X_GET_Y` FREE
  /// reward. `AMOUNT` discounts apply only to the paid units; `PERCENTAGE`
  /// still prices free units at their effective price, so a base-plus-variant
  /// line behaves like an equivalent base-only one.
  static double _calculateDiscountAmount(
    DiscountInput discount,
    List<CartItemData> cartItems,
    double subTotal,
    Map<String, int> freeQtyByCartKey,
  ) {
    if (discount.minPurchase > 0 && subTotal < discount.minPurchase) return 0;

    final cap = discount.maxDiscountAmount;
    final paidItems = <CartItemData>[];
    for (final item in cartItems) {
      final freeQty = freeQtyByCartKey[item.cartKey] ?? 0;
      final paidQty = math.max(0, item.quantity - freeQty);
      if (paidQty <= 0) continue;
      paidItems.add(
        paidQty < item.quantity ? item.copyWith(quantity: paidQty) : item,
      );
    }

    bool isEligible(CartItemData item) {
      switch (discount.scope) {
        case DiscountInput.scopeAll:
          return true;
        case DiscountInput.scopeProduct:
          return discount.eligibleProductIds.contains(item.productId);
        case DiscountInput.scopeCategory:
          return item.categoryIds.any(discount.eligibleCategoryIds.contains);
        default:
          return false;
      }
    }

    if (discount.scope != DiscountInput.scopeAll &&
        discount.scope != DiscountInput.scopeProduct &&
        discount.scope != DiscountInput.scopeCategory) {
      return 0;
    }

    switch (discount.valueType) {
      case DiscountInput.typePercentage:
        final raw = cartItems
            .where(isEligible)
            .fold<double>(
              0,
              (sum, i) => sum + _itemDiscountRounded(i, discount.value),
            );
        return cap != null && cap > 0 ? math.min(raw, cap) : raw;
      case DiscountInput.typeAmount:
        final eligibleSubtotal = paidItems
            .where(isEligible)
            .fold<double>(0, (sum, i) => sum + i.lineSubtotal);
        return math.min(discount.value, eligibleSubtotal);
      default:
        return 0;
    }
  }

  /// One line's percentage discount, rounded to whole rupiah as the server
  /// rounds it.
  static double _itemDiscountRounded(CartItemData item, double percentage) =>
      jvmRound(item.lineSubtotal * percentage / 100.0);

  /// Per-line discount amounts at **full** quantity, with no free-unit
  /// reduction.
  ///
  /// Seeds `EvaluationContext.discountPerCartKey` so `FreeRewardStrategy` can
  /// price a free unit after discount.
  static Map<String, double> _buildDiscountPerCartKey(
    DiscountInput? discount,
    List<CartItemData> cartItems,
    double totalDiscountAmt,
  ) {
    if (discount == null) return const {};

    bool isEligible(CartItemData item) {
      switch (discount.scope) {
        case DiscountInput.scopeAll:
          return true;
        case DiscountInput.scopeProduct:
          return discount.eligibleProductIds.contains(item.productId);
        case DiscountInput.scopeCategory:
          return item.categoryIds.any(discount.eligibleCategoryIds.contains);
        default:
          return false;
      }
    }

    switch (discount.valueType) {
      case DiscountInput.typePercentage:
        return {
          for (final item in cartItems)
            item.cartKey: isEligible(item)
                ? _itemDiscountRounded(item, discount.value)
                : 0.0,
        };

      case DiscountInput.typeAmount:
        if (discount.scope == DiscountInput.scopeProduct) {
          // PRODUCT scope: each eligible line takes min(value, its subtotal)
          // independently.
          return {
            for (final item in cartItems)
              item.cartKey: isEligible(item)
                  ? math.min(discount.value, item.lineSubtotal)
                  : 0.0,
          };
        }
        final eligibleSubtotal = cartItems
            .where(isEligible)
            .fold<double>(0, (sum, i) => sum + i.lineSubtotal);
        if (eligibleSubtotal <= 0) return const {};
        return {
          for (final item in cartItems)
            item.cartKey: isEligible(item)
                ? totalDiscountAmt * item.lineSubtotal / eligibleSubtotal
                : 0.0,
        };

      default:
        return const {};
    }
  }

  /// This line's share of the discount, for the payload rows and tax bases.
  ///
  /// Deliberately **not** the same as the promotion package's helper of the
  /// same name. An uncapped `PERCENTAGE` discount is computed per line here and
  /// still applies to free units, because the server prices a free reward unit
  /// at its post-discount effective price. Everything else — a capped
  /// percentage, or any `AMOUNT` — distributes proportionally and gives free
  /// lines nothing.
  static double _computeItemDiscountAmt(
    CartItemData item,
    DiscountInput? discountInput,
    double totalDiscountAmt,
    List<CartItemData> cartItems, {
    Set<String> freeItemCartKeys = const {},
    bool roundAmountDiscount = true,
  }) {
    if (discountInput == null || totalDiscountAmt <= 0) return 0;

    bool isEligible() {
      switch (discountInput.scope) {
        case DiscountInput.scopeAll:
          return true;
        case DiscountInput.scopeProduct:
          return discountInput.eligibleProductIds.contains(item.productId);
        case DiscountInput.scopeCategory:
          return item.categoryIds.any(
            discountInput.eligibleCategoryIds.contains,
          );
        default:
          return false;
      }
    }

    if (discountInput.valueType == DiscountInput.typePercentage) {
      final cap = discountInput.maxDiscountAmount;
      final isCapActive = cap != null && cap > 0 && totalDiscountAmt >= cap;
      if (!isCapActive) {
        if (!isEligible()) return 0;
        return _itemDiscountRounded(item, discountInput.value);
      }
    }

    if (freeItemCartKeys.contains(item.cartKey)) return 0;

    final paidItems = cartItems
        .where((i) => !freeItemCartKeys.contains(i.cartKey))
        .toList(growable: false);
    final isAmountType = discountInput.valueType == DiscountInput.typeAmount;

    double proportional(double eligibleSubtotal) {
      if (eligibleSubtotal <= 0) return 0;
      final raw = totalDiscountAmt * item.lineSubtotal / eligibleSubtotal;
      return isAmountType && roundAmountDiscount ? jvmRound(raw) : raw;
    }

    switch (discountInput.scope) {
      case DiscountInput.scopeAll:
        return proportional(
          paidItems.fold<double>(0, (sum, i) => sum + i.lineSubtotal),
        );
      case DiscountInput.scopeProduct:
        if (!discountInput.eligibleProductIds.contains(item.productId)) {
          return 0;
        }
        return proportional(
          paidItems
              .where(
                (i) => discountInput.eligibleProductIds.contains(i.productId),
              )
              .fold<double>(0, (sum, i) => sum + i.lineSubtotal),
        );
      case DiscountInput.scopeCategory:
        if (!item.categoryIds.any(discountInput.eligibleCategoryIds.contains)) {
          return 0;
        }
        return proportional(
          paidItems
              .where(
                (i) => i.categoryIds.any(
                  discountInput.eligibleCategoryIds.contains,
                ),
              )
              .fold<double>(0, (sum, i) => sum + i.lineSubtotal),
        );
      default:
        return 0;
    }
  }

  // ─── Free units ───────────────────────────────────────────────────────────

  /// Cart key to the number of units made free by applied FREE promotions.
  ///
  /// A partly-free line appears here — quantity 2 with one free unit maps to 1
  /// — so the discount and tax logic can still charge the remaining unit.
  static Map<String, int> _computeFreeQtyByCartKey(
    List<PromotionInput> appliedFreePromos,
    List<CartItemData> cartItems,
    DiscountInput? discountInput,
    double totalDiscountAmt,
    double subTotal,
    Map<String, double> discountPerCartKey,
  ) {
    if (appliedFreePromos.isEmpty) return const {};

    final ctx = EvaluationContext(
      cartItems: cartItems,
      originalCartItems: cartItems,
      discountInput: discountInput,
      totalDiscountAmt: totalDiscountAmt,
      subTotal: subTotal,
      freeItemCartKeys: const {},
      freeQtyByCartKey: const {},
      discountPerCartKey: discountPerCartKey,
    );

    final freeQtys = <String, int>{};
    for (final promo in appliedFreePromos) {
      final available = promo.selectedRewardQtyMap.isNotEmpty
          ? filterItemsByScope(
                  cartItems,
                  promo.rewardScope,
                  promo.rewardProductIds,
                  promo.rewardCategoryIds,
                )
                .where((i) => promo.selectedRewardQtyMap.containsKey(i.cartKey))
                .map(
                  (i) => i.copyWith(
                    quantity: math.min(
                      i.quantity,
                      promo.selectedRewardQtyMap[i.cartKey] ?? 0,
                    ),
                  ),
                )
                .where((i) => i.quantity > 0)
                .toList(growable: false)
          : _buyXGetY.availableRewardPool(promo, ctx);

      var unitsLeft = promo.getQty ?? 0;
      for (final candidate in sortedByStable(available, (i) => i.price)) {
        if (unitsLeft <= 0) break;
        final units = math.min(unitsLeft, candidate.quantity);
        freeQtys[candidate.cartKey] =
            (freeQtys[candidate.cartKey] ?? 0) + units;
        unitsLeft -= units;
      }
    }
    return freeQtys;
  }

  /// The lines where *every* unit is free.
  ///
  /// Used for the binary checks — tax exclusion in particular. A partly-free
  /// line is not here; quantity-aware logic reads the free-quantity map.
  static Set<String> _fullyFreeCartKeys(
    Map<String, int> freeQtyByCartKey,
    List<CartItemData> cartItems,
  ) {
    final keys = <String>{};
    freeQtyByCartKey.forEach((cartKey, freeQty) {
      final item = cartItems.where((i) => i.cartKey == cartKey).firstOrNull;
      if (item != null && freeQty >= item.quantity) keys.add(cartKey);
    });
    return keys;
  }

  // ─── Tax ──────────────────────────────────────────────────────────────────

  /// One line's tax, on a base already reduced by its deduction share.
  ///
  /// A percentage rate wins over the flat [CartItemData.taxAmountPerUnit],
  /// because the flat figure is the backend's pre-discount snapshot and would
  /// ignore the deduction.
  static double _calculateItemTaxAmount(
    CartItemData item,
    bool priceIncludeTax,
    double deduction,
  ) {
    if (!item.isTaxable) return 0;

    final taxPercentage = item.taxPercentage ?? 0;
    if (taxPercentage > 0) {
      final lineTotal = atLeastZero(item.lineSubtotal - deduction);
      final rate = setScale(taxPercentage / 100.0, 10);
      return priceIncludeTax
          ? setScale(lineTotal * rate / (1 + rate), 10)
          : setScale(lineTotal * rate, 10);
    }

    return setScale(item.taxAmountPerUnit * item.quantity, 2);
  }

  static List<TaxBreakdown> _buildTaxBreakdowns(
    List<CartItemData> cartItems,
    Set<String> freeItemCartKeys,
    bool priceIncludeTax,
    Map<String, double> perItemDeductions,
  ) {
    final grouped = <int?, List<CartItemData>>{};
    for (final item in cartItems) {
      if (!item.isTaxable ||
          item.taxAmountPerUnit <= 0 ||
          freeItemCartKeys.contains(item.cartKey)) {
        continue;
      }
      grouped.putIfAbsent(item.taxId, () => []).add(item);
    }

    return grouped.entries
        .map((entry) {
          final first = entry.value.first;
          final name = first.taxName;
          return TaxBreakdown(
            taxId: entry.key,
            taxName: (name != null && name.isNotEmpty && name != 'none')
                ? name
                : 'Tax',
            taxPercentage: (first.taxPercentage ?? 0) > 0
                ? first.taxPercentage!
                : 0,
            amount: entry.value.fold<double>(
              0,
              (sum, i) =>
                  sum +
                  _calculateItemTaxAmount(
                    i,
                    priceIncludeTax,
                    perItemDeductions[i.cartKey] ?? 0,
                  ),
            ),
          );
        })
        .toList(growable: false);
  }

  /// Cart key to the total deduction — discount plus every promotion type —
  /// that reduces the line's taxable base.
  ///
  /// Covers the manual discount, `DISCOUNT_BY_ORDER`, `DISCOUNT_BY_ITEM_SUBTOTAL`
  /// and non-FREE `BUY_X_GET_Y` rewards. Fully free lines are excluded
  /// entirely; partly free lines have their free units' post-discount value
  /// deducted here.
  static Map<String, double> _computePerItemTotalDeductionByCartKey({
    required List<PromotionInput> promotions,
    required List<int> appliedPromoIds,
    required List<CartItemData> cartItems,
    required Set<String> freeItemCartKeys,
    required Map<String, int> freeQtyByCartKey,
    required DiscountInput? discountInput,
    required double totalDiscountAmt,
    required double subTotal,
    required Map<String, double> discountPerCartKey,
    required Map<int, double> perPromoAmounts,
  }) {
    final amounts = <String, double>{};
    final paidItems = cartItems
        .where((i) => !freeItemCartKeys.contains(i.cartKey))
        .toList(growable: false);

    if (discountInput != null && totalDiscountAmt > 0) {
      for (final item in paidItems) {
        final itemAmt = _computeItemDiscountAmt(
          item,
          discountInput,
          totalDiscountAmt,
          cartItems,
          freeItemCartKeys: freeItemCartKeys,
          roundAmountDiscount: false,
        );
        if (itemAmt > 0) {
          amounts[item.cartKey] = (amounts[item.cartKey] ?? 0) + itemAmt;
        }
      }
    }

    // Partly-free lines: the free units' post-discount value comes off the
    // taxable base too. Fully free lines are already excluded.
    for (final item in paidItems) {
      final freeQty = freeQtyByCartKey[item.cartKey] ?? 0;
      if (freeQty <= 0) continue;
      final discountTotal = discountPerCartKey[item.cartKey] ?? 0;
      final discountPerUnit = item.quantity > 0
          ? discountTotal / item.quantity
          : 0.0;
      amounts[item.cartKey] =
          (amounts[item.cartKey] ?? 0) +
          (item.price - discountPerUnit) * freeQty;
    }

    if (appliedPromoIds.isEmpty) return amounts;

    final promoCtx = EvaluationContext(
      cartItems: paidItems,
      originalCartItems: paidItems,
      discountInput: discountInput,
      totalDiscountAmt: totalDiscountAmt,
      subTotal: subTotal,
      freeItemCartKeys: freeItemCartKeys,
      freeQtyByCartKey: freeQtyByCartKey,
    );
    _orchestrator
        .computeAllPerItemDeductions(
          promotions,
          appliedPromoIds,
          promoCtx,
          perPromoAmounts,
        )
        .forEach((key, amt) {
          if (amt > 0) amounts[key] = (amounts[key] ?? 0) + amt;
        });

    return amounts;
  }

  // ─── Transaction lines ────────────────────────────────────────────────────

  /// A line without the per-item breakdown arrays.
  ///
  /// `buildTransactionPayload` replaces these with fuller ones when it has the
  /// cart to work from; this shape is what the result carries for display.
  static RequestTransactionItem _buildPlainTransactionItem(
    CartItemData item,
    bool priceIncludeTax,
    double itemTaxAmount,
  ) {
    final hasTax = item.isTaxable && itemTaxAmount > 0;

    if (priceIncludeTax) {
      return RequestTransactionItem(
        productId: item.productId,
        productName: item.productName,
        price: formatDecimalFixed2(item.price),
        qty: item.quantity,
        totalPrice: formatDecimalFixed2(item.lineSubtotal),
        taxId: item.isTaxable ? item.taxId : null,
        taxAmount: hasTax ? formatDecimalFixed2(itemTaxAmount) : null,
        variantId: item.variantId,
        variantOptionIds: buildVariantOptionIds(item.selectedVariants),
        details: buildItemDetails(
          item.selectedVariants,
          item.selectedModifiers,
        ),
      );
    }

    return RequestTransactionItem(
      productId: item.productId,
      productName: item.productName,
      price: jvmRound(item.price).toInt().toString(),
      qty: item.quantity,
      totalPrice: formatDecimalUpTo2(item.lineSubtotal + itemTaxAmount),
      taxId: item.isTaxable ? item.taxId : null,
      taxAmount: hasTax ? formatDecimalUpTo2(itemTaxAmount) : null,
      variantId: item.variantId,
      variantOptionIds: buildVariantOptionIds(item.selectedVariants),
      details: buildItemDetails(item.selectedVariants, item.selectedModifiers),
    );
  }
}

/// The chosen variant option ids, or null when the line has none.
List<int>? buildVariantOptionIds(List<VariantOption> variants) =>
    variants.isEmpty ? null : variants.map((v) => v.id).toList(growable: false);

/// Variant then modifier rows, numbered in the order they were chosen.
List<RequestItemDetail>? buildItemDetails(
  List<VariantOption> variants,
  List<ModifierOption> modifiers,
) {
  if (variants.isEmpty && modifiers.isEmpty) return null;

  final details = <RequestItemDetail>[];
  var sortOrder = 0;
  for (final variant in variants) {
    details.add(
      RequestItemDetail(
        detailType: RequestItemDetail.typeVariant,
        name: variant.name,
        groupName: variant.groupName,
        referenceId: variant.id,
        groupReferenceId: variant.variantGroupId,
        priceAdjustment: variant.additionalPrice,
        qty: 1,
        sortOrder: sortOrder++,
      ),
    );
  }
  for (final modifier in modifiers) {
    details.add(
      RequestItemDetail(
        detailType: RequestItemDetail.typeModifier,
        name: modifier.name,
        groupName: modifier.groupName,
        referenceId: modifier.id,
        groupReferenceId: modifier.groupId,
        priceAdjustment: modifier.additionalPrice,
        qty: 1,
        sortOrder: sortOrder++,
      ),
    );
  }
  return details;
}
