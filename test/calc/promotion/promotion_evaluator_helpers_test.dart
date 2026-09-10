import 'package:cashup_pos/src/calc/calculator_models.dart';
import 'package:cashup_pos/src/calc/promotion/evaluation_context.dart';
import 'package:cashup_pos/src/calc/promotion/promotion_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

CartItemData item(
  int id,
  double price,
  int qty, {
  List<int> categories = const [],
  String? cartKey,
}) => CartItemData(
  productId: id,
  productName: 'P$id',
  price: price,
  quantity: qty,
  categoryIds: categories,
  cartKey: cartKey ?? '$id',
);

EvaluationContext context(
  List<CartItemData> cart, {
  DiscountInput? discount,
  double totalDiscountAmt = 0,
  Set<String> freeItemCartKeys = const {},
  Map<String, double> discountPerCartKey = const {},
}) => EvaluationContext(
  cartItems: cart,
  originalCartItems: cart,
  discountInput: discount,
  totalDiscountAmt: totalDiscountAmt,
  subTotal: cart.fold(0, (sum, i) => sum + i.lineSubtotal),
  freeItemCartKeys: freeItemCartKeys,
  freeQtyByCartKey: const {},
  discountPerCartKey: discountPerCartKey,
);

void main() {
  group('filterItemsByScope', () {
    final cart = [
      item(1, 10000, 1, categories: [5]),
      item(2, 20000, 1),
    ];

    test('ALL returns every line', () {
      expect(filterItemsByScope(cart, 'ALL', const [], const []).length, 2);
    });

    test('PRODUCT keeps only listed product ids', () {
      expect(
        filterItemsByScope(cart, 'PRODUCT', const [
          2,
        ], const []).single.productId,
        2,
      );
    });

    test('CATEGORY keeps lines with a matching category', () {
      expect(
        filterItemsByScope(cart, 'CATEGORY', const [], const [
          5,
        ]).single.productId,
        1,
      );
    });

    test('an unrecognised scope falls through to ALL, as Kotlin does', () {
      expect(filterItemsByScope(cart, 'WOBBLE', const [], const []).length, 2);
    });

    test('an empty id list under PRODUCT scope matches nothing', () {
      expect(filterItemsByScope(cart, 'PRODUCT', const [], const []), isEmpty);
    });
  });

  group('computeItemDiscountAmt', () {
    test(
      'AMOUNT scope=ALL distributes proportionally and rounds each share',
      () {
        final cart = [item(1, 10000, 1), item(2, 20000, 1)];
        const discount = DiscountInput(valueType: 'AMOUNT', value: 5000);
        // 10000/30000 * 5000 = 1666.67 -> 1667 (Math.round on the share)
        expect(computeItemDiscountAmt(cart[0], discount, 5000, cart), 1667.0);
      },
    );

    test('the raw share is used when rounding is suppressed for tax bases', () {
      final cart = [item(1, 10000, 1), item(2, 20000, 1)];
      const discount = DiscountInput(valueType: 'AMOUNT', value: 5000);
      expect(
        computeItemDiscountAmt(
          cart[0],
          discount,
          5000,
          cart,
          roundAmountDiscount: false,
        ),
        closeTo(1666.666, 0.001),
      );
    });

    test('PERCENTAGE shares are never rounded by this helper', () {
      final cart = [item(1, 10000, 1), item(2, 20000, 1)];
      const discount = DiscountInput(valueType: 'PERCENTAGE', value: 10);
      // 3000 total, of which this line carries 1/3.
      expect(computeItemDiscountAmt(cart[0], discount, 3000, cart), 1000.0);
    });

    test('a fully free line takes no discount share', () {
      final cart = [item(1, 10000, 1), item(2, 20000, 1)];
      const discount = DiscountInput(valueType: 'AMOUNT', value: 5000);
      expect(
        computeItemDiscountAmt(
          cart[0],
          discount,
          5000,
          cart,
          freeItemCartKeys: {'1'},
        ),
        0.0,
      );
    });

    test('free lines are excluded from the denominator too', () {
      final cart = [item(1, 10000, 1), item(2, 20000, 1)];
      const discount = DiscountInput(valueType: 'AMOUNT', value: 5000);
      // Line 1 is free, so line 2 carries the whole 5000 rather than 2/3.
      expect(
        computeItemDiscountAmt(
          cart[1],
          discount,
          5000,
          cart,
          freeItemCartKeys: {'1'},
        ),
        5000.0,
      );
    });

    test('PRODUCT scope gives nothing to an ineligible line', () {
      final cart = [item(1, 10000, 1), item(2, 20000, 1)];
      const discount = DiscountInput(
        valueType: 'AMOUNT',
        value: 5000,
        scope: 'PRODUCT',
        eligibleProductIds: [2],
      );
      expect(computeItemDiscountAmt(cart[0], discount, 5000, cart), 0.0);
      expect(computeItemDiscountAmt(cart[1], discount, 5000, cart), 5000.0);
    });

    test('CATEGORY scope splits only across eligible lines', () {
      final cart = [
        item(1, 10000, 1, categories: [5]),
        item(2, 30000, 1, categories: [5]),
        item(3, 60000, 1),
      ];
      const discount = DiscountInput(
        valueType: 'AMOUNT',
        value: 4000,
        scope: 'CATEGORY',
        eligibleCategoryIds: [5],
      );
      // Eligible subtotal is 40000, so line 1 takes a quarter.
      expect(computeItemDiscountAmt(cart[0], discount, 4000, cart), 1000.0);
      expect(computeItemDiscountAmt(cart[2], discount, 4000, cart), 0.0);
    });

    test(
      'a zero eligible subtotal yields nothing rather than dividing by zero',
      () {
        final cart = [item(1, 0, 1)];
        const discount = DiscountInput(valueType: 'AMOUNT', value: 5000);
        expect(computeItemDiscountAmt(cart[0], discount, 5000, cart), 0.0);
      },
    );
  });

  group('netPricePerUnit', () {
    test('returns the gross price when there is no discount', () {
      final cart = [item(1, 10000, 2)];
      expect(netPricePerUnit(cart[0], context(cart)), 10000.0);
    });

    test('subtracts the line share spread over its units', () {
      final cart = [item(1, 10000, 2), item(2, 20000, 1)];
      const discount = DiscountInput(valueType: 'AMOUNT', value: 4000);
      final ctx = context(cart, discount: discount, totalDiscountAmt: 4000);
      // Line 1 carries 20000/40000 of 4000 = 2000, over two units.
      expect(netPricePerUnit(cart[0], ctx), 9000.0);
    });

    test('never goes below zero when the discount exceeds the line', () {
      final cart = [item(1, 1000, 1)];
      const discount = DiscountInput(valueType: 'AMOUNT', value: 5000);
      final ctx = context(cart, discount: discount, totalDiscountAmt: 5000);
      expect(netPricePerUnit(cart[0], ctx), 0.0);
    });

    test('uses originalCartItems as the denominator, not the reduced cart', () {
      final original = [item(1, 10000, 2), item(2, 10000, 2)];
      // A prior promo claimed one unit of line 1, so the working cart is smaller.
      final reduced = [original[0].copyWith(quantity: 1), original[1]];
      const discount = DiscountInput(valueType: 'AMOUNT', value: 4000);
      final ctx = EvaluationContext(
        cartItems: reduced,
        originalCartItems: original,
        discountInput: discount,
        totalDiscountAmt: 4000,
        subTotal: 40000,
        freeItemCartKeys: const {},
        freeQtyByCartKey: const {},
      );
      // Denominator stays the original 40000, so the share is not inflated by
      // the claimed unit: 10000/40000 * 4000 = 1000 over one unit.
      expect(netPricePerUnit(reduced[0], ctx), 9000.0);
    });
  });

  group('EvaluationContext', () {
    test('copyWith replaces only the named fields', () {
      final cart = [item(1, 10000, 1)];
      final ctx = context(cart);
      final reduced = ctx.copyWith(cartItems: const [], subTotal: 0);

      expect(reduced.cartItems, isEmpty);
      expect(reduced.subTotal, 0);
      expect(reduced.originalCartItems, ctx.originalCartItems);
    });
  });

  group('ItemPromoRole', () {
    test('copyWith rescales the amount and keeps the rest', () {
      const role = ItemPromoRole(
        promotionId: 7,
        promoType: 'DISCOUNT_BY_ORDER',
        role: 'REWARD',
        amt: 1000,
        buyQty: 2,
        getQty: 1,
      );
      final scaled = role.copyWith(amt: 900);
      expect(scaled.amt, 900);
      expect(scaled.promotionId, 7);
      expect(scaled.role, 'REWARD');
      expect(scaled.buyQty, 2);
    });
  });
}
