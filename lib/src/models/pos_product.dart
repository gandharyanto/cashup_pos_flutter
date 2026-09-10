import '../util/num_utils.dart';
import 'pos_category.dart';

/// The tax attached to a product, when it is taxable.
class PosTax {
  const PosTax({this.taxId, this.taxName, this.taxPercentage, this.taxAmount});

  final int? taxId;
  final String? taxName;
  final double? taxPercentage;
  final double? taxAmount;

  factory PosTax.fromJson(Map<String, dynamic> json) => PosTax(
    taxId: asInt(json['taxId']),
    taxName: json['taxName'] as String?,
    taxPercentage: asDouble(json['taxPercentage']),
    taxAmount: asDouble(json['taxAmount']),
  );

  Map<String, dynamic> toJson() => {
    'taxId': taxId,
    'taxName': taxName,
    'taxPercentage': taxPercentage,
    'taxAmount': taxAmount,
  };
}

/// One entry of a product's `productImages` array.
class PosProductImage {
  const PosProductImage({this.id, this.thumbImage, this.fullImage});

  final int? id;
  final String? thumbImage;
  final String? fullImage;

  factory PosProductImage.fromJson(Map<String, dynamic> json) =>
      PosProductImage(
        id: asInt(json['id']),
        thumbImage: json['thumbImage'] as String?,
        fullImage: json['fullImage'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'thumbImage': thumbImage,
    'fullImage': fullImage,
  };
}

/// A sellable product.
///
/// Note the two price fields. The cart always prices from [basePrice] — the
/// Kotlin `ProductItem.price` getter returns `basePrice`, and
/// `SharedPosViewModel` builds every line from it. [finalPrice] is the
/// backend's post-tax figure and is display-only.
class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    this.sku,
    this.upc,
    this.imageUrl,
    this.imageThumbUrl,
    this.description,
    this.basePrice = 0,
    this.finalPrice = 0,
    this.isPriceIncludeTax = false,
    this.isTaxable = false,
    this.isPriceAdjustable = false,
    this.isUnlimitedStock = false,
    this.hasModifiers = false,
    this.tax,
    this.qty = 0,
    this.categories = const [],
    this.images = const [],
    this.productType = typeSimple,
  });

  static const String typeSimple = 'SIMPLE';
  static const String typeVariant = 'VARIANT';
  static const String typeModifier = 'MODIFIER';

  final int id;
  final String name;
  final String? sku;
  final String? upc;
  final String? imageUrl;
  final String? imageThumbUrl;
  final String? description;
  final double basePrice;
  final double finalPrice;
  final bool isPriceIncludeTax;
  final bool isTaxable;
  final bool isPriceAdjustable;
  final bool isUnlimitedStock;
  final bool hasModifiers;
  final PosTax? tax;
  final int qty;
  final List<PosCategory> categories;
  final List<PosProductImage> images;
  final String productType;

  bool get isVariant => productType == typeVariant;
  bool get isModifier => productType == typeModifier;
  bool get isSimple => productType == typeSimple;

  List<int> get categoryIds =>
      categories.map((c) => c.id).toList(growable: false);

  /// Mirrors `ProductItem.getEffectiveImageUrl()`: the flat field wins when
  /// non-empty, otherwise the first entry of `productImages`.
  String? get effectiveImageUrl {
    final flat = imageUrl;
    if (flat != null && flat.isNotEmpty) return flat;
    return images.isEmpty ? null : images.first.fullImage;
  }

  String? get effectiveThumbUrl {
    final flat = imageThumbUrl;
    if (flat != null && flat.isNotEmpty) return flat;
    return images.isEmpty ? null : images.first.thumbImage;
  }

  factory PosProduct.fromJson(Map<String, dynamic> json) => PosProduct(
    id: asInt(json['id']) ?? 0,
    name: json['name'] as String? ?? '',
    sku: json['sku'] as String?,
    upc: json['upc'] as String?,
    imageUrl: json['imageUrl'] as String?,
    imageThumbUrl: json['imageThumbUrl'] as String?,
    description: json['description'] as String?,
    basePrice: asDouble(json['basePrice']) ?? 0,
    finalPrice:
        asDouble(json['finalPrice']) ?? asDouble(json['basePrice']) ?? 0,
    isPriceIncludeTax: asBool(json['isPriceIncludeTax']) ?? false,
    isTaxable: asBool(json['isTaxable']) ?? false,
    isPriceAdjustable: asBool(json['isPriceAdjustable']) ?? false,
    isUnlimitedStock: asBool(json['isUnlimitedStock']) ?? false,
    hasModifiers: asBool(json['hasModifiers']) ?? false,
    tax: json['tax'] is Map
        ? PosTax.fromJson(Map<String, dynamic>.from(json['tax'] as Map))
        : null,
    qty: asInt(json['qty']) ?? 0,
    categories:
        (json['categories'] as List?)
            ?.whereType<Map>()
            .map((e) => PosCategory.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false) ??
        const [],
    images:
        (json['productImages'] as List?)
            ?.whereType<Map>()
            .map((e) => PosProductImage.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false) ??
        const [],
    productType: json['productType'] as String? ?? typeSimple,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'upc': upc,
    'imageUrl': imageUrl,
    'imageThumbUrl': imageThumbUrl,
    'description': description,
    'basePrice': basePrice,
    'finalPrice': finalPrice,
    'isPriceIncludeTax': isPriceIncludeTax,
    'isTaxable': isTaxable,
    'isPriceAdjustable': isPriceAdjustable,
    'isUnlimitedStock': isUnlimitedStock,
    'hasModifiers': hasModifiers,
    'tax': tax?.toJson(),
    'qty': qty,
    'categories': categories.map((c) => c.toJson()).toList(growable: false),
    'productImages': images.map((i) => i.toJson()).toList(growable: false),
    'productType': productType,
  };
}
