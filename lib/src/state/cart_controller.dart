import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/option_group.dart';
import '../models/pos_product.dart';
import '../util/cart_key.dart';

/// A uniquely configured product line in the cart.
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

  double get effectivePrice =>
      (customBasePrice ?? product.basePrice) +
      selectedVariants.fold(0, (sum, option) => sum + option.additionalPrice) +
      selectedModifiers.fold(0, (sum, option) => sum + option.additionalPrice);

  String get displayName {
    if (selectedVariants.isEmpty) return product.name;
    return '${product.name} (${selectedVariants.map((v) => v.name).join(', ')})';
  }

  String get optionsSummary =>
      selectedModifiers.map((option) => option.name).join(', ');

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

/// Immutable cart contents and transaction metadata entered by the cashier.
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
      lines.values.fold(0, (sum, line) => sum + line.lineTotal);
  bool get isEmpty => lines.isEmpty;

  CartState copyWith({
    Map<String, PosCartLine>? lines,
    String? Function()? notes,
    String? Function()? customerName,
    String? Function()? queueNumber,
  }) => CartState(
    lines: lines ?? this.lines,
    notes: notes == null ? this.notes : notes(),
    customerName: customerName == null ? this.customerName : customerName(),
    queueNumber: queueNumber == null ? this.queueNumber : queueNumber(),
  );
}

/// Owns cart mutations and enforces the product stock ceiling.
class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Adds [quantity] to a configured product line.
  ///
  /// Returns `null` on success, otherwise the Indonesian stock error shown to
  /// the cashier. Unlimited-stock products bypass the guard.
  String? add(
    PosProduct product, {
    List<VariantOption> variants = const [],
    List<ModifierOption> modifiers = const [],
    double? customBasePrice,
    int quantity = 1,
  }) {
    if (quantity <= 0) return null;
    final cartKey = buildCartKey(
      productId: product.id,
      variants: variants,
      modifiers: modifiers,
      customBasePrice: customBasePrice,
      isPriceAdjustable: product.isPriceAdjustable,
    );
    final current = state.lines[cartKey];
    final nextQuantity = (current?.quantity ?? 0) + quantity;
    final error = _stockError(product, nextQuantity);
    if (error != null) return error;

    final updated = Map<String, PosCartLine>.of(state.lines);
    updated[cartKey] =
        current?.copyWith(quantity: nextQuantity) ??
        PosCartLine(
          product: product,
          quantity: quantity,
          selectedVariants: List.unmodifiable(variants),
          selectedModifiers: List.unmodifiable(modifiers),
          customBasePrice: customBasePrice,
          cartKey: cartKey,
        );
    state = state.copyWith(lines: Map.unmodifiable(updated));
    return null;
  }

  void setQuantity(String cartKey, int quantity) {
    final current = state.lines[cartKey];
    if (current == null) return;
    if (quantity <= 0) {
      remove(cartKey);
      return;
    }
    if (_stockError(current.product, quantity) != null ||
        current.quantity == quantity) {
      return;
    }
    final updated = Map<String, PosCartLine>.of(state.lines)
      ..[cartKey] = current.copyWith(quantity: quantity);
    state = state.copyWith(lines: Map.unmodifiable(updated));
  }

  void remove(String cartKey) {
    if (!state.lines.containsKey(cartKey)) return;
    final updated = Map<String, PosCartLine>.of(state.lines)..remove(cartKey);
    state = state.copyWith(lines: Map.unmodifiable(updated));
  }

  void clear() => state = const CartState();

  void setNotes(String? notes) => state = state.copyWith(notes: () => notes);

  String? _stockError(PosProduct product, int requestedQuantity) {
    if (product.isUnlimitedStock || requestedQuantity <= product.qty) {
      return null;
    }
    return 'Stok ${product.name} tidak mencukupi. '
        'Stok tersedia: ${product.qty}';
  }
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

/// Narrow selector so a row rebuilds only when its own line changes.
final cartLineProvider = Provider.family<PosCartLine?, String>(
  (ref, cartKey) =>
      ref.watch(cartControllerProvider.select((cart) => cart.lines[cartKey])),
);
