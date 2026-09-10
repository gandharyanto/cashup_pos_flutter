import '../util/num_utils.dart';

/// A page of results from a `/pos/*` list endpoint.
///
/// The backend wraps every list in the same envelope:
/// `{status, message, meta: {baseUrl}, data: [...], page, size, totalElements,
/// totalPages}`. [baseUrl] is carried alongside the items because image paths
/// in the payload are relative to it.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    this.baseUrl,
    this.page = 0,
    this.size = 0,
    this.totalElements = 0,
    this.totalPages = 0,
  });

  final List<T> items;
  final String? baseUrl;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  /// Whether another page exists after this one.
  bool get hasMore => page + 1 < totalPages;

  bool get isEmpty => items.isEmpty;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    final data = json['data'];
    return PagedResult<T>(
      items: data is List
          ? data
                .whereType<Map>()
                .map((e) => itemFromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
          : const [],
      baseUrl: _baseUrl(json['meta']),
      page: asInt(json['page']) ?? 0,
      size: asInt(json['size']) ?? 0,
      totalElements: asInt(json['totalElements']) ?? 0,
      totalPages: asInt(json['totalPages']) ?? 0,
    );
  }

  /// Wraps an already-materialised list, for endpoints that return a bare
  /// array rather than a paged envelope.
  factory PagedResult.single(List<T> items, {String? baseUrl}) =>
      PagedResult<T>(
        items: items,
        baseUrl: baseUrl,
        size: items.length,
        totalElements: items.length,
        totalPages: items.isEmpty ? 0 : 1,
      );

  static String? _baseUrl(Object? meta) {
    if (meta is Map) return meta['baseUrl'] as String?;
    return null;
  }
}
