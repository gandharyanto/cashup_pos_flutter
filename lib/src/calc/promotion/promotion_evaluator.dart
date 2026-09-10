import 'package:collection/collection.dart';

import '../../util/num_utils.dart';
import '../calculator_models.dart';
import 'evaluation_context.dart';

/// What one promotion type knows how to do.
///
/// One implementation per `promoType`. Keeping them apart is deliberate: in
/// the Kotlin original every type shared a single `when` block, and a fix to
/// one repeatedly shifted the others.
abstract class PromotionEvaluator {
  const PromotionEvaluator();

  /// The total amount this promotion takes off the order.
  double evaluate(PromotionInput promo, EvaluationContext ctx);

  /// How that amount is attributed across lines, keyed by cart key.
  ///
  /// Feeds each line's taxable base, which the backend re-validates.
  Map<String, double> perItemDeduction(
    PromotionInput promo,
    EvaluationContext ctx,
  );

  /// Why [item] participates, for the payload's per-item promotion array.
  List<ItemPromoRole> itemRole(
    PromotionInput promo,
    CartItemData item,
    EvaluationContext ctx,
  );
}

/// One line's part in one promotion, as reported in the transaction payload.
class ItemPromoRole {
  const ItemPromoRole({
    required this.promotionId,
    required this.promoType,
    required this.role,
    required this.amt,
    this.buyQty,
    this.getQty,
  });

  static const String qualifier = 'QUALIFIER';
  static const String reward = 'REWARD';

  final int promotionId;
  final String promoType;

  /// `QUALIFIER` or `REWARD`.
  final String role;

  final double amt;
  final int? buyQty;
  final int? getQty;

  ItemPromoRole copyWith({double? amt}) => ItemPromoRole(
    promotionId: promotionId,
    promoType: promoType,
    role: role,
    amt: amt ?? this.amt,
    buyQty: buyQty,
    getQty: getQty,
  );
}

/// Narrows [cartItems] to the lines a scope covers.
///
/// An unrecognised scope falls through to `ALL`, matching the Kotlin `when`
/// so that a new backend scope degrades rather than dropping every line.
List<CartItemData> filterItemsByScope(
  List<CartItemData> cartItems,
  String scope,
  List<int> productIds,
  List<int> categoryIds,
) {
  switch (scope) {
    case DiscountInput.scopeProduct:
      return cartItems
          .where((i) => productIds.contains(i.productId))
          .toList(growable: false);
    case DiscountInput.scopeCategory:
      return cartItems
          .where((i) => i.categoryIds.any(categoryIds.contains))
          .toList(growable: false);
    default:
      return cartItems;
  }
}

/// This line's share of the manual discount.
///
/// `AMOUNT` discounts distribute proportionally and each share is rounded to
/// the nearest rupiah for the rows that appear in the payload — the backend
/// rounds the same way, and summing unrounded shares diverges by a rupiah.
/// Callers deriving a *tax base* pass `roundAmountDiscount: false`, because
/// the backend validates tax against the raw share.
///
/// Lines in [freeItemCartKeys] take no share and are excluded from the
/// denominator: a fully free line is out of the order entirely.
double computeItemDiscountAmt(
  CartItemData item,
  DiscountInput discountInput,
  double totalDiscountAmt,
  List<CartItemData> cartItems, {
  Set<String> freeItemCartKeys = const {},
  bool roundAmountDiscount = true,
}) {
  if (freeItemCartKeys.contains(item.cartKey)) return 0;

  final paidItems = cartItems
      .where((i) => !freeItemCartKeys.contains(i.cartKey))
      .toList(growable: false);
  final itemSubtotal = item.lineSubtotal;
  final isAmountType = discountInput.valueType == DiscountInput.typeAmount;

  double proportional(double eligibleSubtotal) {
    if (eligibleSubtotal <= 0) return 0;
    final raw = totalDiscountAmt * itemSubtotal / eligibleSubtotal;
    return isAmountType && roundAmountDiscount ? jvmRound(raw) : raw;
  }

  double subtotalOf(bool Function(CartItemData) predicate) => paidItems
      .where(predicate)
      .fold<double>(0, (sum, i) => sum + i.lineSubtotal);

  switch (discountInput.scope) {
    case DiscountInput.scopeProduct:
      if (!discountInput.eligibleProductIds.contains(item.productId)) return 0;
      return proportional(
        subtotalOf(
          (i) => discountInput.eligibleProductIds.contains(i.productId),
        ),
      );
    case DiscountInput.scopeCategory:
      if (!item.categoryIds.any(discountInput.eligibleCategoryIds.contains)) {
        return 0;
      }
      return proportional(
        subtotalOf(
          (i) => i.categoryIds.any(discountInput.eligibleCategoryIds.contains),
        ),
      );
    case DiscountInput.scopeAll:
      return proportional(subtotalOf((_) => true));
    default:
      return 0;
  }
}

/// What one unit of [item] actually costs after its discount share.
///
/// Reward amounts are computed against this rather than the gross price, so
/// a promotion's value matches what the customer pays.
double netPricePerUnit(
  CartItemData item,
  EvaluationContext ctx, {
  Set<String>? freeItemCartKeys,
  bool roundAmountDiscount = false,
}) {
  final discountInput = ctx.discountInput;
  if (discountInput == null ||
      ctx.totalDiscountAmt <= 0 ||
      item.quantity <= 0) {
    return item.price;
  }
  final share = computeItemDiscountAmt(
    item,
    discountInput,
    ctx.totalDiscountAmt,
    ctx.originalCartItems,
    freeItemCartKeys: freeItemCartKeys ?? ctx.freeItemCartKeys,
    roundAmountDiscount: roundAmountDiscount,
  );
  final netSubtotal = atLeastZero(item.lineSubtotal - share);
  return netSubtotal / item.quantity;
}

/// Sorts by [key] the way Kotlin's `sortedBy` does — **stably**.
///
/// Dart's [List.sort] is introsort and reorders equal elements. Kotlin's is
/// stable, and the difference is observable here: when two reward candidates
/// share a price, which one gets claimed decides the product id recorded in
/// `claimedRewardUnits`, and therefore which line a later promotion can still
/// reward. Cart order has to survive the sort.
List<CartItemData> sortedByStable(
  List<CartItemData> items,
  double Function(CartItemData item) key, {
  bool descending = false,
}) {
  final sorted = List<CartItemData>.of(items);
  mergeSort<CartItemData>(
    sorted,
    compare: (a, b) =>
        descending ? key(b).compareTo(key(a)) : key(a).compareTo(key(b)),
  );
  return sorted;
}
