import '../util/num_utils.dart';

/// One row of a merchant directory/listing response, from
/// `pos/merchant/list` or `pos/merchant/area/list`.
///
/// Not to be confused with `PosMerchant` in `lib/src/config/pos_config.dart`,
/// which describes the single merchant a host app is configured against
/// (name/address/logo for display), not a listing row.
///
/// **Placeholder path, confirmed item shape.** No merchant-listing endpoint
/// exists in the pinned Kotlin source this package ports from
/// (`origin/feature/pos-asg-phase3` @
/// `33ddffdcc50aa8f9c6c53344bb4b269de5733064`) — this was designed for a
/// user-requested addition with no real backend contract to match yet, so
/// the endpoint *paths* are still placeholders. The item *shape* below,
/// though, is taken verbatim from a real sample response the user supplied:
/// `{"value": 16461, "label": "Misoa Nai Nai (TOKYO WET)"}`. The wire sends
/// no `address`, `logoUrl` or separate area id/name — [name] and [areaName]
/// below are derived from [label] rather than carried as their own fields.
class PosMerchantSummary {
  const PosMerchantSummary({required this.id, required this.label});

  final int id;

  /// The wire's label verbatim, e.g. "Misoa Nai Nai (TOKYO WET)".
  final String label;

  static final _labelPattern = RegExp(r'^(.*)\s\(([^)]+)\)$');

  /// The merchant name with a trailing " (Area)" suffix stripped, when
  /// present. Falls back to the full [label] when the pattern doesn't match
  /// (no parenthesized suffix on the wire).
  String get name {
    final match = _labelPattern.firstMatch(label);
    return match?.group(1) ?? label;
  }

  /// The area name parsed from a trailing "(Area)" suffix, or `null` when
  /// [label] carries none.
  String? get areaName => _labelPattern.firstMatch(label)?.group(2);

  factory PosMerchantSummary.fromJson(Map<String, dynamic> json) =>
      PosMerchantSummary(
        id: asInt(json['value']) ?? 0,
        label: json['label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosMerchantSummary && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}
