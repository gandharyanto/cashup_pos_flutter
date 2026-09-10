import '../../util/num_utils.dart';
import '../calculator_models.dart';
import 'buyxgety/buy_x_get_y_evaluator.dart';
import 'discount_by_item_subtotal_evaluator.dart';
import 'discount_by_order_evaluator.dart';
import 'evaluation_context.dart';
import 'promotion_evaluator.dart';

/// What [PromotionOrchestrator.evaluateAll] found.
class PromotionEvaluationOutcome {
  const PromotionEvaluationOutcome({
    required this.totalAmount,
    required this.appliedIds,
    required this.perPromoAmounts,
  });

  const PromotionEvaluationOutcome.none()
    : totalAmount = 0,
      appliedIds = const [],
      perPromoAmounts = const {};

  final double totalAmount;
  final List<int> appliedIds;

  /// Each applied promotion's own contribution, keyed by promotion id.
  final Map<int, double> perPromoAmounts;
}

/// One `BUY_X_GET_Y` application's qualifier consumption.
///
/// [qty] units of [buyProductId] were spent qualifying, which blocks their
/// reuse by a later promotion whose reward scope overlaps [rewardProductIds].
///
/// Recorded **once per promotion application**, not once per reward product in
/// scope. Recording it per product was a real bug: a promotion with a wide
/// reward catalogue had its single consumption counted several times, which
/// wrongly zeroed the qualifier stock and blocked the next promotion even when
/// a second physical qualifier unit was sitting in the cart.
class _QualifierConsumption {
  const _QualifierConsumption(
    this.buyProductId,
    this.rewardProductIds,
    this.qty,
  );

  final int buyProductId;
  final Set<int> rewardProductIds;
  final int qty;
}

/// Runs every promotion against the cart in the right order and stops them
/// stepping on each other.
///
/// Two forms of bookkeeping do that work: claimed reward units (no physical
/// unit is rewarded twice) and consumed qualifiers (no physical unit qualifies
/// twice).
class PromotionOrchestrator {
  const PromotionOrchestrator();

  static const _buyXGetY = BuyXGetYEvaluator();

  static const Map<String, PromotionEvaluator> _evaluators = {
    PromotionInput.typeDiscountByOrder: DiscountByOrderEvaluator(),
    PromotionInput.typeDiscountByItemSubtotal:
        DiscountByItemSubtotalEvaluator(),
    PromotionInput.typeBuyXGetY: _buyXGetY,
  };

  /// Evaluates [promotions] in order: FREE `BUY_X_GET_Y` first, then by
  /// priority ascending, then by id. A promotion with `canCombine == false`
  /// ends evaluation once it applies.
  PromotionEvaluationOutcome evaluateAll(
    List<PromotionInput> promotions,
    EvaluationContext baseCtx,
  ) {
    if (promotions.isEmpty) return const PromotionEvaluationOutcome.none();

    var totalPromoAmount = 0.0;

    // Only a fully FREE reward takes an item out of the order, so only its
    // gross price is excluded from later promotions' base. The other reward
    // types are per-item discounts — the item stays in the order, and letting
    // them shrink a later promotion's base would understate it. Confirmed
    // against production validation of isolated single-promotion transactions.
    var freeGrossExclusion = 0.0;

    final appliedIds = <int>[];
    final perPromoAmounts = <int, double>{};
    final claimedRewardUnits = <int, int>{};
    final qualifierConsumed = <_QualifierConsumption>[];

    for (final promo in _sorted(promotions)) {
      if (baseCtx.subTotal < promo.minPurchase) continue;
      if (!_meetsBuyQuantity(promo, baseCtx, qualifierConsumed)) continue;
      if (promo.isBuyXGetY &&
          !_hasUnclaimedRewardUnits(promo, baseCtx, claimedRewardUnits)) {
        continue;
      }

      final promoSubTotal = atLeastZero(baseCtx.subTotal - freeGrossExclusion);
      final effectiveCtx = promo.isBuyXGetY
          ? baseCtx.copyWith(
              cartItems: _reducedCart(
                promo,
                baseCtx,
                claimedRewardUnits,
                qualifierConsumed,
              ),
              subTotal: promoSubTotal,
            )
          : baseCtx.copyWith(subTotal: promoSubTotal);

      final evaluator = _evaluators[promo.promoType];
      if (evaluator == null) continue;

      final rawAmount = evaluator.evaluate(promo, effectiveCtx);
      // Only DISCOUNT_BY_ORDER's contribution is rounded before it reaches
      // totalPromotionAmount — the backend validates the others unrounded.
      final amount = promo.promoType == PromotionInput.typeDiscountByOrder
          ? jvmRound(rawAmount)
          : rawAmount;
      if (amount <= 0) continue;

      totalPromoAmount += amount;
      perPromoAmounts[promo.promotionId] = amount;
      appliedIds.add(promo.promotionId);

      if (promo.isBuyXGetY) {
        final claimed = _buyXGetY.claimedRewardUnits(promo, effectiveCtx);
        claimed.forEach((productId, qty) {
          claimedRewardUnits[productId] =
              (claimedRewardUnits[productId] ?? 0) + qty;
        });

        if (promo.isFreeReward) {
          // The item leaves the order at its **gross** value, not the
          // post-discount value that totalPromoAmount credits.
          claimed.forEach((productId, qty) {
            final item = effectiveCtx.cartItems
                .where((i) => i.productId == productId)
                .firstOrNull;
            freeGrossExclusion += (item?.price ?? 0) * qty;
          });
        }

        _consumeQualifiers(promo, effectiveCtx, qualifierConsumed);
      }

      if (!promo.canCombine) break;
    }

    return PromotionEvaluationOutcome(
      totalAmount: totalPromoAmount,
      appliedIds: appliedIds,
      perPromoAmounts: perPromoAmounts,
    );
  }

  /// Every applied promotion's per-item deductions, summed by cart key.
  ///
  /// [perPromoAmounts] carries each promotion's authoritative contribution from
  /// [evaluateAll]'s sequential pass. `DISCOUNT_BY_ORDER`'s base shifts when an
  /// earlier FREE reward removed an item, but `perItemDeduction` here runs
  /// against a separately-built, non-reduced context — so its shares are
  /// rescaled to sum to the authoritative total instead of drifting from it.
  /// Other types evaluate the same items regardless of `subTotal`, so they stay
  /// at scale 1.0.
  Map<String, double> computeAllPerItemDeductions(
    List<PromotionInput> promotions,
    List<int> appliedIds,
    EvaluationContext ctx, [
    Map<int, double> perPromoAmounts = const {},
  ]) {
    final amounts = <String, double>{};
    for (final promo in promotions.where(
      (p) => appliedIds.contains(p.promotionId),
    )) {
      final evaluator = _evaluators[promo.promoType];
      if (evaluator == null) continue;

      final rawPerItem = evaluator.perItemDeduction(promo, ctx);
      final scale = _rescaleFactor(promo, rawPerItem, perPromoAmounts);
      rawPerItem.forEach((key, amt) {
        amounts[key] = (amounts[key] ?? 0) + amt * scale;
      });
    }
    return amounts;
  }

  /// Every role [item] plays across the applied promotions.
  ///
  /// See [computeAllPerItemDeductions] for why [perPromoAmounts] rescaling is
  /// needed.
  List<ItemPromoRole> computeAllItemRoles(
    CartItemData item,
    List<PromotionInput> promotions,
    List<int> appliedIds,
    EvaluationContext ctx, [
    Map<int, double> perPromoAmounts = const {},
  ]) {
    if (appliedIds.isEmpty) return const [];

    final roles = <ItemPromoRole>[];
    for (final promo in promotions.where(
      (p) => appliedIds.contains(p.promotionId),
    )) {
      final evaluator = _evaluators[promo.promoType];
      if (evaluator == null) continue;

      final promoRoles = evaluator.itemRole(promo, item, ctx);
      if (promoRoles.isEmpty ||
          promo.promoType != PromotionInput.typeDiscountByOrder) {
        roles.addAll(promoRoles);
        continue;
      }

      final scale = _rescaleFactor(
        promo,
        evaluator.perItemDeduction(promo, ctx),
        perPromoAmounts,
      );
      roles.addAll(promoRoles.map((r) => r.copyWith(amt: r.amt * scale)));
    }
    return roles;
  }

  // ─── Ordering and eligibility ─────────────────────────────────────────────

  List<PromotionInput> _sorted(List<PromotionInput> promotions) {
    final sorted = List<PromotionInput>.of(promotions);
    sorted.sort((a, b) {
      final aFree = a.isBuyXGetY && a.isFreeReward ? 0 : 1;
      final bFree = b.isBuyXGetY && b.isFreeReward ? 0 : 1;
      if (aFree != bFree) return aFree.compareTo(bFree);
      if (a.priority != b.priority) return a.priority.compareTo(b.priority);
      return a.promotionId.compareTo(b.promotionId);
    });
    return sorted;
  }

  bool _meetsBuyQuantity(
    PromotionInput promo,
    EvaluationContext ctx,
    List<_QualifierConsumption> qualifierConsumed,
  ) {
    final buyQty = promo.buyQty ?? 0;
    if (buyQty <= 0 || promo.promoType == PromotionInput.typeDiscountByOrder) {
      return true;
    }

    switch (promo.promoType) {
      case PromotionInput.typeDiscountByItemSubtotal:
        final eligibleQty = filterItemsByScope(
          ctx.cartItems,
          promo.buyScope,
          promo.buyProductIds,
          promo.buyCategoryIds,
        ).fold<int>(0, (sum, i) => sum + i.quantity);
        return eligibleQty >= buyQty;

      case PromotionInput.typeBuyXGetY:
        final currentRewardPids = _rewardProductIds(promo, ctx);
        final eligibleQty =
            filterItemsByScope(
              ctx.cartItems,
              promo.buyScope,
              promo.buyProductIds,
              promo.buyCategoryIds,
            ).fold<int>(0, (sum, item) {
              final consumed = _consumedFor(
                qualifierConsumed,
                item.productId,
                currentRewardPids,
              );
              return sum + (item.quantity - consumed).clamp(0, item.quantity);
            });
        return eligibleQty >= buyQty;

      default:
        return false;
    }
  }

  bool _hasUnclaimedRewardUnits(
    PromotionInput promo,
    EvaluationContext ctx,
    Map<int, int> claimedRewardUnits,
  ) => filterItemsByScope(
    ctx.cartItems,
    promo.rewardScope,
    promo.rewardProductIds,
    promo.rewardCategoryIds,
  ).any((i) => (i.quantity - (claimedRewardUnits[i.productId] ?? 0)) > 0);

  /// The cart as this promotion sees it: units already claimed as rewards, and
  /// qualifiers already spent on an overlapping reward scope, are removed.
  List<CartItemData> _reducedCart(
    PromotionInput promo,
    EvaluationContext ctx,
    Map<int, int> claimedRewardUnits,
    List<_QualifierConsumption> qualifierConsumed,
  ) {
    final currentRewardPids = _rewardProductIds(promo, ctx);
    return ctx.cartItems
        .map((item) {
          final claimedReward = claimedRewardUnits[item.productId] ?? 0;
          final claimedQualifier = _consumedFor(
            qualifierConsumed,
            item.productId,
            currentRewardPids,
          );
          final total = claimedReward + claimedQualifier;
          return total > 0
              ? item.copyWith(
                  quantity: (item.quantity - total).clamp(0, item.quantity),
                )
              : item;
        })
        .toList(growable: false);
  }

  void _consumeQualifiers(
    PromotionInput promo,
    EvaluationContext ctx,
    List<_QualifierConsumption> qualifierConsumed,
  ) {
    final buyItems = filterItemsByScope(
      ctx.cartItems,
      promo.buyScope,
      promo.buyProductIds,
      promo.buyCategoryIds,
    );
    final rewardPids = _rewardProductIds(promo, ctx);

    var qualifiersLeft = promo.buyQty ?? 1;
    for (final item in buyItems) {
      if (qualifiersLeft <= 0) break;
      final toConsume = qualifiersLeft < item.quantity
          ? qualifiersLeft
          : item.quantity;
      if (toConsume <= 0) continue;
      qualifierConsumed.add(
        _QualifierConsumption(item.productId, rewardPids, toConsume),
      );
      qualifiersLeft -= toConsume;
    }
  }

  Set<int> _rewardProductIds(PromotionInput promo, EvaluationContext ctx) =>
      filterItemsByScope(
        ctx.cartItems,
        promo.rewardScope,
        promo.rewardProductIds,
        promo.rewardCategoryIds,
      ).map((i) => i.productId).toSet();

  int _consumedFor(
    List<_QualifierConsumption> qualifierConsumed,
    int productId,
    Set<int> currentRewardPids,
  ) => qualifierConsumed
      .where(
        (c) =>
            c.buyProductId == productId &&
            c.rewardProductIds.any(currentRewardPids.contains),
      )
      .fold<int>(0, (sum, c) => sum + c.qty);

  double _rescaleFactor(
    PromotionInput promo,
    Map<String, double> rawPerItem,
    Map<int, double> perPromoAmounts,
  ) {
    if (promo.promoType != PromotionInput.typeDiscountByOrder) return 1;
    final authoritative = perPromoAmounts[promo.promotionId];
    if (authoritative == null) return 1;
    final rawSum = rawPerItem.values.fold<double>(0, (sum, v) => sum + v);
    return rawSum > 0 ? authoritative / rawSum : 1;
  }
}
