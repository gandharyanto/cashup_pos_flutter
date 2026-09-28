import '../util/num_utils.dart';

/// One row of a merchant directory/listing response, from
/// `pos/merchant/list` or `pos/merchant/area/list`.
///
/// Not to be confused with `PosMerchant` in `lib/src/config/pos_config.dart`,
/// which describes the single merchant a host app is configured against
/// (name/address/logo for display), not a listing row.
///
/// **Placeholder contract.** No merchant-listing endpoint exists in the
/// pinned Kotlin source this package ports from
/// (`origin/feature/pos-asg-phase3` @
/// `33ddffdcc50aa8f9c6c53344bb4b269de5733064`) — this shape was designed for
/// a user-requested addition with no real backend contract to match yet.
/// Check the current backend before relying on the field names here.
class PosMerchantSummary {
  const PosMerchantSummary({
    required this.id,
    required this.name,
    this.address,
    this.areaId,
    this.areaName,
    this.logoUrl,
  });

  final int id;
  final String name;
  final String? address;
  final int? areaId;
  final String? areaName;
  final String? logoUrl;

  factory PosMerchantSummary.fromJson(Map<String, dynamic> json) =>
      PosMerchantSummary(
        id: asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        address: json['address'] as String?,
        areaId: asInt(json['areaId']),
        areaName: json['areaName'] as String?,
        logoUrl: json['logoUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'areaId': areaId,
    'areaName': areaName,
    'logoUrl': logoUrl,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosMerchantSummary &&
          other.id == id &&
          other.name == name &&
          other.address == address &&
          other.areaId == areaId &&
          other.areaName == areaName &&
          other.logoUrl == logoUrl;

  @override
  int get hashCode => Object.hash(id, name, address, areaId, areaName, logoUrl);
}
