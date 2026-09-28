import '../models/option_group.dart';

/// Builds the stable identifier used for both cart lines and per-line savings.
///
/// Variant IDs retain selection order, while modifier IDs are sorted so the
/// same modifier set cannot create duplicate lines merely because it was
/// selected in a different order. This mirrors Kotlin's `buildCartKey`.
String buildCartKey({
  required int productId,
  List<VariantOption> variants = const [],
  List<ModifierOption> modifiers = const [],
  double? customBasePrice,
  bool isPriceAdjustable = false,
}) {
  final variantPart = variants.isEmpty
      ? ''
      : '_v${variants.map((option) => option.id).join('-')}';
  final sortedModifierIds = modifiers.map((option) => option.id).toList()
    ..sort();
  final modifierPart = sortedModifierIds.isEmpty
      ? ''
      : '_m${sortedModifierIds.join('-')}';
  final pricePart = isPriceAdjustable && customBasePrice != null
      ? '_p${customBasePrice.toInt()}'
      : '';
  return '$productId$variantPart$modifierPart$pricePart';
}
