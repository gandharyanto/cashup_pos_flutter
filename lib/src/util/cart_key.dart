/// Builds the cart's per-line key, mirroring
/// `SharedPosViewModel.buildCartKey` exactly — the calculation engine keys
/// per-line savings off this string, so the format must not drift.
///
/// Shape: `"$productId"` plus, when present:
/// * `_v<variantId>-<variantId>...` — variant ids in selection order.
/// * `_m<modifierId>-<modifierId>...` — modifier ids sorted ascending.
/// * `_p<customBasePrice>` — only when [isPriceAdjustable] is true and
///   [customBasePrice] was actually overridden.
library;

import '../models/option_group.dart';

String buildCartKey({
  required int productId,
  List<VariantOption> variants = const [],
  List<ModifierOption> modifiers = const [],
  double? customBasePrice,
  bool isPriceAdjustable = false,
}) {
  final buffer = StringBuffer('$productId');

  if (variants.isNotEmpty) {
    buffer.write('_v${variants.map((v) => v.id).join('-')}');
  }

  if (modifiers.isNotEmpty) {
    final sortedIds = modifiers.map((m) => m.id).toList()..sort();
    buffer.write('_m${sortedIds.join('-')}');
  }

  if (isPriceAdjustable && customBasePrice != null) {
    buffer.write('_p${customBasePrice.toInt()}');
  }

  return buffer.toString();
}
