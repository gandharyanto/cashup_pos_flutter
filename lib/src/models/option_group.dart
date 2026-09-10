import '../util/num_utils.dart';

/// One selectable option inside an [OptionGroup].
class OptionItem {
  const OptionItem({
    required this.optionId,
    required this.name,
    this.variantId,
    this.priceAdjustment = 0,
    this.qty = 0,
    this.isUnlimitedStock = false,
    this.isOptional = false,
    this.displayOrder = 0,
  });

  final int optionId;
  final int? variantId;
  final String name;
  final double priceAdjustment;
  final int qty;
  final bool isUnlimitedStock;
  final bool isOptional;
  final int displayOrder;

  factory OptionItem.fromJson(Map<String, dynamic> json) => OptionItem(
    optionId: asInt(json['optionId']) ?? 0,
    variantId: asInt(json['variantId']),
    name: json['name'] as String? ?? '',
    priceAdjustment: asDouble(json['priceAdjustment']) ?? 0,
    qty: asInt(json['qty']) ?? 0,
    isUnlimitedStock: asBool(json['isUnlimitedStock']) ?? false,
    isOptional: asBool(json['isOptional']) ?? false,
    displayOrder: asInt(json['displayOrder']) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'optionId': optionId,
    'variantId': variantId,
    'name': name,
    'priceAdjustment': priceAdjustment,
    'qty': qty,
    'isUnlimitedStock': isUnlimitedStock,
    'isOptional': isOptional,
    'displayOrder': displayOrder,
  };
}

/// A group of options attached to a product — a variant axis such as "Ukuran",
/// or a modifier set such as "Topping".
///
/// Selection rules, mirroring `PosProductVariantBottomSheet`:
/// * `selectionType == 'SINGLE'` renders as radio buttons (exactly one choice)
/// * `selectionType == 'MULTIPLE'` renders as checkboxes bounded by
///   [minSelection] and [maxSelection]
/// * a required group must reach [effectiveMinSelection] before confirming
class OptionGroup {
  const OptionGroup({
    required this.groupId,
    required this.name,
    required this.groupType,
    this.selectionType,
    this.isCombinationMember = false,
    this.isRequired = false,
    this.minSelection = 0,
    this.maxSelection = 0,
    this.options = const [],
  });

  static const String typeVariant = 'VARIANT';
  static const String typeModifier = 'MODIFIER';
  static const String selectionSingle = 'SINGLE';
  static const String selectionMultiple = 'MULTIPLE';

  final int groupId;
  final String name;
  final String groupType;
  final String? selectionType;
  final bool isCombinationMember;
  final bool isRequired;
  final int minSelection;
  final int maxSelection;
  final List<OptionItem> options;

  /// Variant groups are single-selection by nature; modifier groups follow
  /// their declared [selectionType].
  bool get isSingleSelection =>
      groupType == typeVariant || selectionType == selectionSingle;

  /// A required group needs at least one selection even when the backend
  /// reports `minSelection: 0` — the Kotlin sheet applies the same coercion.
  int get effectiveMinSelection =>
      isRequired && minSelection < 1 ? 1 : minSelection;

  /// Zero or a negative value means "no upper bound".
  bool get hasSelectionLimit => maxSelection > 0;

  factory OptionGroup.fromJson(Map<String, dynamic> json) => OptionGroup(
    groupId: asInt(json['groupId']) ?? 0,
    name: json['name'] as String? ?? '',
    groupType: json['groupType'] as String? ?? typeModifier,
    selectionType: json['selectionType'] as String?,
    isCombinationMember: asBool(json['isCombinationMember']) ?? false,
    isRequired: asBool(json['isRequired']) ?? false,
    minSelection: asInt(json['minSelection']) ?? 0,
    maxSelection: asInt(json['maxSelection']) ?? 0,
    options:
        (json['options'] as List?)
            ?.whereType<Map>()
            .map((e) => OptionItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false) ??
        const [],
  );

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'name': name,
    'groupType': groupType,
    'selectionType': selectionType,
    'isCombinationMember': isCombinationMember,
    'isRequired': isRequired,
    'minSelection': minSelection,
    'maxSelection': maxSelection,
    'options': options.map((o) => o.toJson()).toList(growable: false),
  };
}

/// The `pos/product/{id}/option-groups` payload.
class ProductOptionGroups {
  const ProductOptionGroups({
    required this.productId,
    required this.productType,
    this.isPriceAdjustable = false,
    this.variantGroups = const [],
    this.modifierGroups = const [],
  });

  final int productId;
  final String productType;
  final bool isPriceAdjustable;
  final List<OptionGroup> variantGroups;
  final List<OptionGroup> modifierGroups;

  /// Whether the product needs the selection sheet at all. A product with no
  /// options is added to the cart directly.
  bool get hasAnyOption =>
      variantGroups.isNotEmpty || modifierGroups.isNotEmpty;

  factory ProductOptionGroups.fromJson(Map<String, dynamic> json) =>
      ProductOptionGroups(
        productId: asInt(json['productId']) ?? 0,
        productType: json['productType'] as String? ?? 'SIMPLE',
        isPriceAdjustable: asBool(json['isPriceAdjustable']) ?? false,
        variantGroups: _groups(json['variantGroups']),
        modifierGroups: _groups(json['modifierGroups']),
      );

  static List<OptionGroup> _groups(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => OptionGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}

/// A variant the cashier chose, in the shape the cart and the transaction
/// payload need.
class VariantOption {
  const VariantOption({
    required this.id,
    required this.variantGroupId,
    required this.name,
    this.additionalPrice = 0,
    this.groupName = '',
    this.sku,
  });

  final int id;
  final int variantGroupId;
  final String name;
  final double additionalPrice;
  final String groupName;
  final String? sku;

  /// Maps a chosen [OptionItem] into the cart layer's shape, mirroring the
  /// mapping `PosProductVariantBottomSheet` performs on confirm.
  factory VariantOption.fromOption(OptionItem option, OptionGroup group) =>
      VariantOption(
        id: option.optionId,
        variantGroupId: group.groupId,
        name: option.name,
        additionalPrice: option.priceAdjustment,
        groupName: group.name,
      );

  factory VariantOption.fromJson(Map<String, dynamic> json) => VariantOption(
    id: asInt(json['id']) ?? 0,
    variantGroupId: asInt(json['variantGroupId']) ?? 0,
    name: json['name'] as String? ?? '',
    additionalPrice: asDouble(json['additionalPrice']) ?? 0,
    groupName: json['groupName'] as String? ?? '',
    sku: json['sku'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'variantGroupId': variantGroupId,
    'name': name,
    'additionalPrice': additionalPrice,
    'groupName': groupName,
    'sku': sku,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariantOption &&
          other.id == id &&
          other.variantGroupId == variantGroupId &&
          other.additionalPrice == additionalPrice;

  @override
  int get hashCode => Object.hash(id, variantGroupId, additionalPrice);
}

/// A modifier the cashier chose, in the shape the cart and the transaction
/// payload need.
class ModifierOption {
  const ModifierOption({
    required this.id,
    required this.productId,
    required this.name,
    this.additionalPrice = 0,
    this.groupId = 0,
    this.groupName = '',
  });

  final int id;
  final int productId;
  final String name;
  final double additionalPrice;
  final int groupId;
  final String groupName;

  /// Mirrors the `ModifierOption` construction in the Kotlin sheet, which
  /// builds every option of a group up-front for price lookup.
  factory ModifierOption.fromOption(
    OptionItem option,
    OptionGroup group, {
    required int productId,
  }) => ModifierOption(
    id: option.optionId,
    productId: productId,
    name: option.name,
    additionalPrice: option.priceAdjustment,
    groupId: group.groupId,
    groupName: group.name,
  );

  factory ModifierOption.fromJson(Map<String, dynamic> json) => ModifierOption(
    id: asInt(json['id']) ?? 0,
    productId: asInt(json['productId']) ?? 0,
    name: json['name'] as String? ?? '',
    additionalPrice: asDouble(json['additionalPrice']) ?? 0,
    groupId: asInt(json['groupId']) ?? 0,
    groupName: json['groupName'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'name': name,
    'additionalPrice': additionalPrice,
    'groupId': groupId,
    'groupName': groupName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModifierOption &&
          other.id == id &&
          other.groupId == groupId &&
          other.additionalPrice == additionalPrice;

  @override
  int get hashCode => Object.hash(id, groupId, additionalPrice);
}
