import '../util/num_utils.dart';

/// An operating area, as returned by the area-listing endpoint.
///
/// **Placeholder path, confirmed item shape.** No `area list` endpoint
/// exists in the pinned Kotlin source this package ports from
/// (`origin/feature/pos-asg-phase3` @
/// `33ddffdcc50aa8f9c6c53344bb4b269de5733064`) — this was designed for a
/// user-requested addition with no real backend contract to match yet, so
/// the endpoint *path* is still a placeholder. The item *shape* below,
/// though, mirrors a real sample response the user supplied for the sibling
/// merchant-listing endpoints (`{value, label}`), which the user confirmed
/// should be assumed for this endpoint too, since no separate area sample
/// exists yet. Re-check both against the current backend before relying on
/// them.
class PosArea {
  const PosArea({required this.id, required this.name});

  final int id;
  final String name;

  /// Reads the wire's `value`/`label` keys into this package's own
  /// `id`/`name` shape.
  factory PosArea.fromJson(Map<String, dynamic> json) => PosArea(
    id: asInt(json['value']) ?? 0,
    name: json['label'] as String? ?? '',
  );

  /// Emits this package's own canonical `{id, name}` shape. This does not
  /// round-trip back to the wire's `value`/`label` keys — nothing currently
  /// serializes a [PosArea] back to the wire.
  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosArea && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
