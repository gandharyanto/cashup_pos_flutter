import 'dart:math' as math;

import '../../calculator_models.dart';
import '../evaluation_context.dart';
import '../promotion_evaluator.dart';
import 'amount_reward_strategy.dart';
import 'fixed_price_reward_strategy.dart';
import 'free_reward_strategy.dart';
import 'percentage_reward_strategy.dart';
import 'reward_strategy.dart';

/// "Buy X, get Y" — the promotion type with all the edge cases.
///
/// This class owns the *who gets the reward* question; the four
/// [RewardStrategy] implementations own *what the reward is worth*. The split
/// exists because in the Kotlin original the two were tangled, and a fix to
/// one reward type kept shifting the others.
///
/// The hard part is that buy and reward scopes can overlap. When they do, some
/// units are consumed as qualifiers and cannot also be rewarded — "no reward
/// without a qualifier" is the invariant every helper below protects.
class BuyXGetYEvaluator extends PromotionEvaluator {
  const BuyXGetYEvaluator();

  static const _free = FreeRewardStrategy();
  static const _percentage = PercentageRewardStrategy();
  static const _amount = AmountRewardStrategy();
  static const _fixedPrice = FixedPriceRewardStrategy();

  @override
  double evaluate(PromotionInput promo, EvaluationContext ctx) {
    final rewardType = promo.rewardType;
    if (rewardType == null) return 0;
    final strategy = _strategyFor(rewardType);
    if (strategy == null) return 0;

    final effectiveRewardQty = _computeEffectiveRewardQty(promo, ctx.cartItems);
    if (effectiveRewardQty <= 0) return 0;

    final buyItems = _buyItems(promo, ctx.cartItems);
    final rewardItems = _rewardItems(promo, ctx.cartItems, ctx);
    final availablePool = _buildAvailableRewardItems(
      buyItems,
      rewardItems,
      promo.buyQty ?? 1,
      ctx,
    );
    final availableRewardItems = _resolveRewardItems(
      promo,
      buyItems,
      rewardItems,
      availablePool,
      ctx,
    );
    if (availableRewardItems.isEmpty) return 0;

    return strategy.calculateAmount(
      availableRewardItems,
      effectiveRewardQty,
      promo,
      ctx,
    );
  }

  @override
  Map<String, double> perItemDeduction(
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    // A FREE reward is applied by zeroing the line through freeItemCartKeys in
    // the calculator, so there is no per-item deduction to report here.
    if (promo.rewardType == PromotionInput.rewardFree) return const {};

    final promoAmount = evaluate(promo, ctx);
    if (promoAmount <= 0) return const {};

    if (promo.rewardType == PromotionInput.rewardAmount ||
        promo.rewardType == PromotionInput.rewardFixedPrice) {
      return _fixedValueRewardDeductions(promo, ctx);
    }

    final buyItems = _buyItems(promo, ctx.cartItems);
    final rewardItems = _rewardItems(promo, ctx.cartItems, ctx)
        .where((i) => !ctx.freeItemCartKeys.contains(i.cartKey))
        .toList(growable: false);

    final effectiveRewardItems = _hasExplicitSelection(promo)
        ? _selectedRewardItems(promo, rewardItems)
        : _buildAvailableRewardItems(
            buyItems,
            rewardItems,
            promo.buyQty ?? 1,
            ctx,
          );

    final rewardSubtotal = effectiveRewardItems.fold<double>(
      0,
      (sum, i) => sum + _rewardNetPricePerUnit(i, promo, ctx) * i.quantity,
    );
    if (rewardSubtotal <= 0) return const {};

    final deductions = <String, double>{};
    for (final item in effectiveRewardItems) {
      final itemNetPrice = _rewardNetPricePerUnit(item, promo, ctx);
      final amount =
          promoAmount * (itemNetPrice * item.quantity) / rewardSubtotal;
      if (amount > 0) deductions[item.cartKey] = amount;
    }
    return deductions;
  }

  @override
  List<ItemPromoRole> itemRole(
    PromotionInput promo,
    CartItemData item,
    EvaluationContext ctx,
  ) {
    final buyItemsInCart = _buyItems(promo, ctx.cartItems);
    final rewardItemsInCart = _rewardItems(promo, ctx.cartItems, ctx);
    final hasOverlap = buyItemsInCart.any(
      (buy) => rewardItemsInCart.any((r) => r.productId == buy.productId),
    );

    if (hasOverlap) {
      return _overlappingRoles(
        promo,
        item,
        ctx,
        buyItemsInCart,
        rewardItemsInCart,
      );
    }

    final isReward = _hasExplicitSelection(promo)
        ? promo.selectedRewardQtyMap.containsKey(item.cartKey)
        : filterItemsByScope(
            [item],
            promo.rewardScope,
            promo.rewardProductIds,
            promo.rewardCategoryIds,
          ).isNotEmpty;

    if (isReward) {
      final effectiveRewardItems = _hasExplicitSelection(promo)
          ? _selectedRewardItems(promo, rewardItemsInCart)
          : rewardItemsInCart;
      return [
        ItemPromoRole(
          promotionId: promo.promotionId,
          promoType: promo.promoType,
          role: ItemPromoRole.reward,
          amt: _rewardAmountFor(item, promo, ctx, effectiveRewardItems),
          buyQty: promo.buyQty,
          getQty: promo.getQty,
        ),
      ];
    }

    final isBuyer = filterItemsByScope(
      [item],
      promo.buyScope,
      promo.buyProductIds,
      promo.buyCategoryIds,
    ).isNotEmpty;
    if (!isBuyer) return const [];

    final qualifierKeys = _qualifierKeys(
      buyItemsInCart,
      promo.buyQty ?? 1,
      ctx,
    );
    if (!qualifierKeys.contains(item.cartKey)) return const [];
    return [
      ItemPromoRole(
        promotionId: promo.promotionId,
        promoType: promo.promoType,
        role: ItemPromoRole.qualifier,
        amt: 0,
        buyQty: promo.buyQty,
        getQty: promo.getQty,
      ),
    ];
  }

  /// The reward candidates left once qualifier-reserved units are removed.
  ///
  /// The calculator needs this to work out which cart lines a FREE reward
  /// actually zeroes; exposing it here keeps that logic in one place rather
  /// than duplicated, as the Kotlin original had it.
  List<CartItemData> availableRewardPool(
    PromotionInput promo,
    EvaluationContext ctx,
  ) => _buildAvailableRewardItems(
    _buyItems(promo, ctx.cartItems),
    _rewardItems(promo, ctx.cartItems, ctx),
    promo.buyQty ?? 1,
    ctx,
  );

  /// Product id to the number of reward units this promotion consumes.
  ///
  /// The orchestrator tracks these across promotions so no physical unit is
  /// rewarded twice.
  Map<int, int> claimedRewardUnits(
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    final buyItems = _buyItems(promo, ctx.cartItems);
    final rewardItems = _rewardItems(promo, ctx.cartItems, ctx);
    final available = _buildAvailableRewardItems(
      buyItems,
      rewardItems,
      promo.buyQty ?? 1,
      ctx,
    );

    var unitsLeft = _computeEffectiveRewardQty(promo, ctx.cartItems);
    if (unitsLeft <= 0) return const {};

    final claimed = <int, int>{};
    for (final item in sortedByStable(
      available,
      (i) => netPricePerUnit(i, ctx),
    )) {
      if (unitsLeft <= 0) break;
      final toMark = math.min(unitsLeft, item.quantity);
      if (toMark > 0) {
        claimed[item.productId] = (claimed[item.productId] ?? 0) + toMark;
        unitsLeft -= toMark;
      }
    }
    return claimed;
  }

  // ─── Roles when buy and reward scopes overlap ──────────────────────────────

  List<ItemPromoRole> _overlappingRoles(
    PromotionInput promo,
    CartItemData item,
    EvaluationContext ctx,
    List<CartItemData> buyItemsInCart,
    List<CartItemData> rewardItemsInCart,
  ) {
    final buyQty = promo.buyQty ?? 0;
    final availablePool = _buildAvailableRewardItems(
      buyItemsInCart,
      rewardItemsInCart,
      buyQty,
      ctx,
    );
    final effectivePool = _resolveRewardItems(
      promo,
      buyItemsInCart,
      rewardItemsInCart,
      availablePool,
      ctx,
    );

    final rewardProductIds = <int>{};
    final rewardCartKeys = <String>{};
    var rewardUnitsLeft = promo.getQty ?? 0;
    for (final candidate in sortedByStable(
      effectivePool,
      (i) => netPricePerUnit(i, ctx),
    )) {
      if (rewardUnitsLeft <= 0) break;
      rewardCartKeys.add(candidate.cartKey);
      rewardProductIds.add(candidate.productId);
      rewardUnitsLeft -= math.min(rewardUnitsLeft, candidate.quantity);
    }

    // Prefer non-reward lines as qualifiers so a reward-only line is not also
    // consumed as a qualifier. When every buy line is also a reward line — a
    // self-referential BUY N GET M on one product — the same line has to carry
    // both roles, so fall back to the full buy list.
    final nonRewardBuyItems = buyItemsInCart
        .where((i) => !rewardProductIds.contains(i.productId))
        .toList(growable: false);
    final qualifierCandidates = nonRewardBuyItems.isEmpty
        ? buyItemsInCart
        : nonRewardBuyItems;
    final qualifierCartKeys = _qualifierKeys(
      qualifierCandidates,
      promo.buyQty ?? 1,
      ctx,
    );

    final isThisItemReward = _hasExplicitSelection(promo)
        ? rewardCartKeys.contains(item.cartKey)
        : rewardProductIds.contains(item.productId);

    final roles = <ItemPromoRole>[];
    if (isThisItemReward) {
      final rewardItems = effectivePool
          .where((i) => rewardProductIds.contains(i.productId))
          .toList(growable: false);
      roles.add(
        ItemPromoRole(
          promotionId: promo.promotionId,
          promoType: promo.promoType,
          role: ItemPromoRole.reward,
          amt: _rewardAmountFor(item, promo, ctx, rewardItems),
          buyQty: promo.buyQty,
          getQty: promo.getQty,
        ),
      );
    }
    if (qualifierCartKeys.contains(item.cartKey)) {
      roles.add(
        ItemPromoRole(
          promotionId: promo.promotionId,
          promoType: promo.promoType,
          role: ItemPromoRole.qualifier,
          amt: 0,
          buyQty: promo.buyQty,
          getQty: promo.getQty,
        ),
      );
    }
    return roles;
  }

  /// The lines that satisfy the buy condition, most expensive first — the
  /// expensive units become qualifiers so the cheap ones stay available as
  /// rewards.
  Set<String> _qualifierKeys(
    List<CartItemData> buyItems,
    int buyQty,
    EvaluationContext ctx,
  ) {
    var qtyLeft = buyQty;
    final keys = <String>{};
    for (final candidate in sortedByStable(
      buyItems,
      (i) => netPricePerUnit(i, ctx),
      descending: true,
    )) {
      if (qtyLeft <= 0) break;
      keys.add(candidate.cartKey);
      qtyLeft -= candidate.quantity;
    }
    return keys;
  }

  double _rewardAmountFor(
    CartItemData item,
    PromotionInput promo,
    EvaluationContext ctx,
    List<CartItemData> effectiveRewardItems,
  ) {
    if (promo.rewardType == PromotionInput.rewardAmount ||
        promo.rewardType == PromotionInput.rewardFixedPrice) {
      return _fixedValueRewardDeductions(promo, ctx)[item.cartKey] ?? 0;
    }

    final rewardSubtotal = effectiveRewardItems.fold<double>(
      0,
      (sum, i) => sum + _rewardNetPricePerUnit(i, promo, ctx) * i.quantity,
    );
    if (rewardSubtotal <= 0) return 0;

    final effectiveQty = effectiveRewardItems
        .where((i) => i.cartKey == item.cartKey)
        .map((i) => i.quantity)
        .firstOrNull;
    final itemNetPrice = _rewardNetPricePerUnit(item, promo, ctx);
    return evaluate(promo, ctx) *
        (itemNetPrice * (effectiveQty ?? item.quantity)) /
        rewardSubtotal;
  }

  /// `AMOUNT` and `FIXED_PRICE` cap or reprice **per unit**, so their per-item
  /// deductions are walked unit by unit rather than distributed proportionally.
  Map<String, double> _fixedValueRewardDeductions(
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    final rewardValue = promo.rewardValue;
    if (rewardValue == null) return const {};

    var unitsLeft = _computeEffectiveRewardQty(promo, ctx.cartItems);
    if (unitsLeft <= 0) return const {};

    final buyItems = _buyItems(promo, ctx.cartItems);
    final rewardItems = _rewardItems(promo, ctx.cartItems, ctx)
        .where((i) => !ctx.freeItemCartKeys.contains(i.cartKey))
        .toList(growable: false);
    final availablePool = _buildAvailableRewardItems(
      buyItems,
      rewardItems,
      promo.buyQty ?? 1,
      ctx,
    );
    final effectiveRewardItems = _resolveRewardItems(
      promo,
      buyItems,
      rewardItems,
      availablePool,
      ctx,
    );

    final amounts = <String, double>{};
    for (final item in sortedByStable(
      effectiveRewardItems,
      (i) => netPricePerUnit(i, ctx),
    )) {
      if (unitsLeft <= 0) break;
      final units = math.min(unitsLeft, item.quantity);
      if (units <= 0) continue;

      final itemNetPrice = _rewardNetPricePerUnit(item, promo, ctx);
      final unitDeduction = promo.rewardType == PromotionInput.rewardAmount
          ? math.min(rewardValue, itemNetPrice)
          : math.max(0.0, itemNetPrice - rewardValue);

      amounts[item.cartKey] =
          (amounts[item.cartKey] ?? 0) + unitDeduction * units;
      unitsLeft -= units;
    }
    amounts.removeWhere((_, value) => value <= 0);
    return amounts;
  }

  // ─── Who is eligible ──────────────────────────────────────────────────────

  List<CartItemData> _buyItems(
    PromotionInput promo,
    List<CartItemData> cartItems,
  ) => filterItemsByScope(
    cartItems,
    promo.buyScope,
    promo.buyProductIds,
    promo.buyCategoryIds,
  );

  List<CartItemData> _rewardItems(
    PromotionInput promo,
    List<CartItemData> cartItems,
    EvaluationContext ctx,
  ) => _filterFixedPriceCandidates(
    filterItemsByScope(
      cartItems,
      promo.rewardScope,
      promo.rewardProductIds,
      promo.rewardCategoryIds,
    ),
    promo,
    ctx,
  );

  /// A `FIXED_PRICE` reward can only apply to units that cost more than the
  /// fixed price — otherwise it would raise the price.
  List<CartItemData> _filterFixedPriceCandidates(
    List<CartItemData> items,
    PromotionInput promo,
    EvaluationContext ctx,
  ) {
    final fixedPrice = promo.rewardValue;
    if (promo.rewardType != PromotionInput.rewardFixedPrice ||
        fixedPrice == null) {
      return items;
    }
    return items
        .where((i) => netPricePerUnit(i, ctx) > fixedPrice)
        .toList(growable: false);
  }

  bool _hasExplicitSelection(PromotionInput promo) =>
      promo.selectedRewardQtyMap.isNotEmpty &&
      promo.rewardScope != PromotionInput.scopeAll;

  List<CartItemData> _selectedRewardItems(
    PromotionInput promo,
    List<CartItemData> rewardItems,
  ) => rewardItems
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
      .toList(growable: false);

  /// Honours the cashier's reward choice, but only when it leaves enough
  /// buy-scope quantity to still satisfy the buy condition.
  ///
  /// Validation runs against the cart directly rather than through
  /// [_buildAvailableRewardItems]: that pool reserves the most expensive units
  /// as qualifiers for *auto*-selection, which would wrongly block a cashier
  /// from choosing an expensive item as the reward.
  List<CartItemData> _resolveRewardItems(
    PromotionInput promo,
    List<CartItemData> buyItems,
    List<CartItemData> rewardItems,
    List<CartItemData> availablePool,
    EvaluationContext ctx,
  ) {
    if (!_hasExplicitSelection(promo)) return availablePool;

    final buyProductIds = buyItems.map((i) => i.productId).toSet();
    final totalBuyQty = ctx.cartItems
        .where((i) => buyProductIds.contains(i.productId))
        .fold<int>(0, (sum, i) => sum + i.quantity);
    final selectedConsumedFromBuy = ctx.cartItems
        .where(
          (i) =>
              promo.selectedRewardQtyMap.containsKey(i.cartKey) &&
              buyProductIds.contains(i.productId),
        )
        .fold<int>(
          0,
          (sum, i) =>
              sum +
              math.min(i.quantity, promo.selectedRewardQtyMap[i.cartKey] ?? 0),
        );

    final selected = _selectedRewardItems(promo, rewardItems);
    final selectionValid =
        (totalBuyQty - selectedConsumedFromBuy) >= (promo.buyQty ?? 1);
    return selectionValid && selected.isNotEmpty ? selected : availablePool;
  }

  // ─── How many units the promotion actually delivers ────────────────────────

  int _computeEffectiveRewardQty(
    PromotionInput promo,
    List<CartItemData> cartItems,
  ) {
    final buyQty = promo.buyQty;
    final getQty = promo.getQty;
    if (buyQty == null || getQty == null) return 0;

    final buyItems = _buyItems(promo, cartItems);
    final eligibleBuyQty = buyItems.fold<int>(0, (sum, i) => sum + i.quantity);
    if (eligibleBuyQty < buyQty) return 0;

    // A discount-free context: this question is about quantities, not money.
    final baseCtx = EvaluationContext(
      cartItems: cartItems,
      originalCartItems: cartItems,
      discountInput: null,
      totalDiscountAmt: 0,
      subTotal: cartItems.fold(0, (sum, i) => sum + i.lineSubtotal),
      freeItemCartKeys: const {},
      freeQtyByCartKey: const {},
    );
    final rewardItems = _rewardItems(promo, cartItems, baseCtx);
    if (rewardItems.isEmpty) return 0;

    final availableRewardQty = _computeAvailableRewardQty(
      buyItems,
      rewardItems,
      buyQty,
    );
    if (availableRewardQty < getQty) return 0;
    if (!promo.isMultiplied) return math.min(getQty, availableRewardQty);

    final hasOverlap = buyItems.any(
      (buy) => rewardItems.any((r) => r.productId == buy.productId),
    );
    final int multiplier;
    if (hasOverlap) {
      final overlapQty = buyItems
          .where((buy) => rewardItems.any((r) => r.productId == buy.productId))
          .fold<int>(0, (sum, i) => sum + i.quantity);
      multiplier = math.max(1, (overlapQty / (buyQty + getQty)).floor());
    } else {
      final buyCycles = (eligibleBuyQty / buyQty).floor();
      final rewardCycles = (availableRewardQty / getQty).floor();
      multiplier = math.max(1, math.min(buyCycles, rewardCycles));
    }
    return math.min(getQty * multiplier, availableRewardQty);
  }

  /// How many reward units survive once the buy condition has taken its share.
  ///
  /// Buy-scope lines that are *not* reward candidates satisfy the condition
  /// without consuming any reward unit, so only the shortfall they cannot
  /// cover is reserved.
  ///
  /// BUY 2 GET 1 on one product: 2 in cart leaves 0 available (not eligible);
  /// 3 in cart leaves 1.
  int _computeAvailableRewardQty(
    List<CartItemData> buyItems,
    List<CartItemData> rewardItems,
    int buyQty,
  ) {
    final buyProductIds = buyItems.map((i) => i.productId).toSet();
    final rewardProductIds = rewardItems.map((i) => i.productId).toSet();

    final overlappingRewardQty = rewardItems
        .where((i) => buyProductIds.contains(i.productId))
        .fold<int>(0, (sum, i) => sum + i.quantity);
    final nonOverlappingRewardQty = rewardItems
        .where((i) => !buyProductIds.contains(i.productId))
        .fold<int>(0, (sum, i) => sum + i.quantity);
    final nonRewardBuyQty = buyItems
        .where((i) => !rewardProductIds.contains(i.productId))
        .fold<int>(0, (sum, i) => sum + i.quantity);

    final unmetBuyQty = math.max(0, buyQty - nonRewardBuyQty);
    final reservedForBuy = math.min(unmetBuyQty, overlappingRewardQty);
    return overlappingRewardQty - reservedForBuy + nonOverlappingRewardQty;
  }

  /// The reward candidates with qualifier-reserved units removed, used for
  /// price selection.
  ///
  /// Single-line overlap reserves per line. Multi-line overlap reserves across
  /// lines starting from the **most expensive**, which become qualifiers and
  /// leave the cheapest available as rewards.
  List<CartItemData> _buildAvailableRewardItems(
    List<CartItemData> buyItems,
    List<CartItemData> rewardItems,
    int buyQty,
    EvaluationContext ctx,
  ) {
    final buyProductIds = buyItems.map((i) => i.productId).toSet();
    final overlapping = rewardItems
        .where((i) => buyProductIds.contains(i.productId))
        .toList(growable: false);
    final nonOverlapping = rewardItems
        .where((i) => !buyProductIds.contains(i.productId))
        .toList(growable: false);

    if (overlapping.isEmpty) {
      return nonOverlapping
          .where((i) => i.quantity > 0)
          .toList(growable: false);
    }

    final rewardProductIds = rewardItems.map((i) => i.productId).toSet();
    final nonRewardBuyQty = buyItems
        .where((i) => !rewardProductIds.contains(i.productId))
        .fold<int>(0, (sum, i) => sum + i.quantity);
    final unmetBuyQty = math.max(0, buyQty - nonRewardBuyQty);

    if (unmetBuyQty == 0) {
      // Non-reward lines already satisfy the buy condition.
      return [
        ...overlapping,
        ...nonOverlapping,
      ].where((i) => i.quantity > 0).toList(growable: false);
    }

    // Line count, not distinct product ids: the same product with different
    // options occupies several lines and must have the reservation spread
    // across them rather than applied per line.
    final isMultiLineOverlap = overlapping.length > 1;
    final List<CartItemData> adjustedOverlap;
    if (isMultiLineOverlap) {
      var reserveLeft = unmetBuyQty;
      adjustedOverlap =
          sortedByStable(
                overlapping,
                (i) => netPricePerUnit(i, ctx),
                descending: true,
              )
              .map((item) {
                final reserved = math.min(reserveLeft, item.quantity);
                reserveLeft -= reserved;
                return item.copyWith(quantity: item.quantity - reserved);
              })
              .toList(growable: false);
    } else {
      adjustedOverlap = overlapping
          .map(
            (item) => item.copyWith(
              quantity: math.max(
                0,
                item.quantity - math.min(unmetBuyQty, item.quantity),
              ),
            ),
          )
          .toList(growable: false);
    }

    return [
      ...adjustedOverlap,
      ...nonOverlapping,
    ].where((i) => i.quantity > 0).toList(growable: false);
  }

  double _rewardNetPricePerUnit(
    CartItemData item,
    PromotionInput promo,
    EvaluationContext ctx,
  ) => netPricePerUnit(
    item,
    ctx,
    roundAmountDiscount: promo.rewardType == PromotionInput.rewardPercentage,
  );

  RewardStrategy? _strategyFor(String rewardType) {
    switch (rewardType) {
      case PromotionInput.rewardFree:
        return _free;
      case PromotionInput.rewardPercentage:
        return _percentage;
      case PromotionInput.rewardAmount:
        return _amount;
      case PromotionInput.rewardFixedPrice:
        return _fixedPrice;
      default:
        return null;
    }
  }
}
