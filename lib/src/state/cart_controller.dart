/// The cart: the in-memory line-item state a cashier builds up before
/// checkout, ported from `SharedPosViewModel`'s `CartItem` /
/// `addToCartWithOptions` / `updateCartQuantity` / `resetCart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/option_group.dart';
import '../models/pos_product.dart';
import '../util/cart_key.dart';

/// One line of the cart — a product plus its selected variants/modifiers and
/// an optional price override, keyed by [cartKey] (see `buildCartKey`).
class PosCartLine {
  const PosCartLine({
    required this.product,
    required this.quantity,
    this.selectedVariants = const [],
    this.selectedModifiers = const [],
    this.customBasePrice,
    required this.cartKey,
  });

  final PosProduct product;
  final int quantity;
  final List<VariantOption> selectedVariants;
  final List<ModifierOption> selectedModifiers;
  final double? customBasePrice;
  final String cartKey;

  /// The per-unit price: the base price (or its override) plus every
  /// selected variant's and modifier's additional price.
  double get effectivePrice {
    final base = customBasePrice ?? product.basePrice;
    final variantAdds = selectedVariants.fold<double>(
      0,
      (sum, v) => sum + v.additionalPrice,
    );
    final modifierAdds = selectedModifiers.fold<double>(
      0,
      (sum, m) => sum + m.additionalPrice,
    );
    return base + variantAdds + modifierAdds;
  }

  /// The product name with selected variant names in parentheses, e.g.
  /// `"Kopi (Large)"`.
  String get displayName {
    if (selectedVariants.isEmpty) return product.name;
    final variantNames = selectedVariants.map((v) => v.name).join(', ');
    return '${product.name} ($variantNames)';
  }

  /// Selected modifier names, comma separated — empty when there are none.
  String get optionsSummary => selectedModifiers.map((m) => m.name).join(', ');

  double get lineTotal => effectivePrice * quantity;

  PosCartLine copyWith({int? quantity}) => PosCartLine(
    product: product,
    quantity: quantity ?? this.quantity,
    selectedVariants: selectedVariants,
    selectedModifiers: selectedModifiers,
    customBasePrice: customBasePrice,
    cartKey: cartKey,
  );
}

/// The cart's lines plus the checkout-adjacent fields the Kotlin view model
/// carries alongside them.
class CartState {
  const CartState({
    this.lines = const {},
    this.notes,
    this.customerName,
    this.queueNumber,
  });

  final Map<String, PosCartLine> lines;
  final String? notes;
  final String? customerName;
  final String? queueNumber;

  int get totalQuantity =>
      lines.values.fold(0, (sum, line) => sum + line.quantity);

  double get subTotal =>
      lines.values.fold(0.0, (sum, line) => sum + line.lineTotal);

  bool get isEmpty => lines.isEmpty;

  CartState copyWith({
    Map<String, PosCartLine>? lines,
    String? notes,
    bool clearNotes = false,
    String? customerName,
    bool clearCustomerName = false,
    String? queueNumber,
    bool clearQueueNumber = false,
  }) => CartState(
    lines: lines ?? this.lines,
    notes: clearNotes ? null : (notes ?? this.notes),
    customerName: clearCustomerName
        ? null
        : (customerName ?? this.customerName),
    queueNumber: clearQueueNumber ? null : (queueNumber ?? this.queueNumber),
  );
}

/// Mutates [CartState] in place, mirroring
/// `SharedPosViewModel.addToCartWithOptions` / `updateCartQuantity` /
/// `resetCart`.
class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Adds [quantity] of [product] (with the given [variants]/[modifiers]/
  /// [customBasePrice]) to the cart, merging onto an existing line with the
  /// same `cartKey` when one exists.
  ///
  /// Returns `null` on success, or an Indonesian error message — mirroring
  /// `_stockValidationError` — when the stock guard rejects it. The guard is
  /// skipped entirely when `product.isUnlimitedStock`.
  String? add(
    PosProduct product, {
    List<VariantOption> variants = const [],
    List<ModifierOption> modifiers = const [],
    double? customBasePrice,
    int quantity = 1,
  }) {
    final cartKey = buildCartKey(
      productId: product.id,
      variants: variants,
      modifiers: modifiers,
      customBasePrice: customBasePrice,
      isPriceAdjustable: product.isPriceAdjustable,
    );

    final lines = state.lines;
    final existing = lines[cartKey];

    if (!product.isUnlimitedStock) {
      final existingQuantity = existing?.quantity ?? 0;
      if (existingQuantity + quantity > product.qty) {
        return 'Stok ${product.name} tidak mencukupi. Stok tersedia: ${product.qty}';
      }
    }

    final updatedLine = existing != null
        ? existing.copyWith(quantity: existing.quantity + quantity)
        : PosCartLine(
            product: product,
            quantity: quantity,
            selectedVariants: variants,
            selectedModifiers: modifiers,
            customBasePrice: customBasePrice,
            cartKey: cartKey,
          );

    state = state.copyWith(lines: {...lines, cartKey: updatedLine});
    return null;
  }

  /// Sets a line's quantity directly. A quantity `<= 0` removes the line.
  void setQuantity(String cartKey, int quantity) {
    if (quantity <= 0) {
      remove(cartKey);
      return;
    }
    final existing = state.lines[cartKey];
    if (existing == null) return;
    state = state.copyWith(
      lines: {
        ...state.lines,
        cartKey: existing.copyWith(quantity: quantity),
      },
    );
  }

  /// Removes a line unconditionally.
  void remove(String cartKey) {
    if (!state.lines.containsKey(cartKey)) return;
    final lines = {...state.lines}..remove(cartKey);
    state = state.copyWith(lines: lines);
  }

  /// Resets the cart entirely — lines and the checkout-adjacent fields alike,
  /// mirroring `resetCart`.
  void clear() {
    state = const CartState();
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes, clearNotes: notes == null);
  }
}

/// The cart: line items plus checkout-adjacent fields (notes, customer,
/// queue number).
final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

/// Narrow selector so a row rebuilds only for its own line.
final cartLineProvider = Provider.family<PosCartLine?, String>(
  (ref, cartKey) =>
      ref.watch(cartControllerProvider.select((s) => s.lines[cartKey])),
);
