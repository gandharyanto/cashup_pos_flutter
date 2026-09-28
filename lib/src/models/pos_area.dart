import '../util/num_utils.dart';

/// An operating area, as returned by `pos/area/list`.
///
/// **Placeholder contract.** No `area list` endpoint exists in the pinned
/// Kotlin source this package ports from (`origin/feature/pos-asg-phase3` @
/// `33ddffdcc50aa8f9c6c53344bb4b269de5733064`) — this shape was designed for
/// a user-requested addition with no real backend contract to match yet.
/// Check the current backend before relying on the field names here.
class PosArea {
  const PosArea({required this.id, required this.name});

  final int id;
  final String name;

  factory PosArea.fromJson(Map<String, dynamic> json) =>
      PosArea(id: asInt(json['id']) ?? 0, name: json['name'] as String? ?? '');

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosArea && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
