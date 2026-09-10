import '../util/num_utils.dart';

/// A product category, as returned by `pos/category/list` and
/// `pos/category/detail/{id}`.
class PosCategory {
  const PosCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
  });

  final int id;
  final String name;
  final String? imageUrl;
  final String? description;

  factory PosCategory.fromJson(Map<String, dynamic> json) => PosCategory(
    id: asInt(json['id']) ?? 0,
    name: json['name'] as String? ?? '',
    imageUrl: json['imageUrl'] as String?,
    description: json['description'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'description': description,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosCategory &&
          other.id == id &&
          other.name == name &&
          other.imageUrl == imageUrl &&
          other.description == description;

  @override
  int get hashCode => Object.hash(id, name, imageUrl, description);
}
