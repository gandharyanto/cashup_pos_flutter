import '../util/num_utils.dart';

/// A page of results from the area/merchant lookup endpoint family.
///
/// These endpoints wrap their list in `{success, data: [...], pagination:
/// {page, limit, hasMore}}` — a different envelope from the rest of
/// `/pos/*`, which uses `{status, message, meta: {baseUrl}, data: [...],
/// page, size, totalElements, totalPages}` (see [PagedResult]). The two are
/// kept as separate types rather than merged into one flexible shape:
/// [PagedResult] already has 22 confirmed call sites depending on its exact
/// fields (`baseUrl`, `totalPages`, ...), and folding this envelope's
/// `hasMore`/`limit` into it would either corrupt that contract or make it
/// ambiguous which fields a given response actually populates.
class PosLookupPage<T> {
  const PosLookupPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  final List<T> items;
  final int page;
  final int limit;
  final bool hasMore;

  factory PosLookupPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    final data = json['data'] as List? ?? const [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? const {};
    return PosLookupPage(
      items: data
          .whereType<Map>()
          .map((e) => itemFromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      page: asInt(pagination['page']) ?? 0,
      limit: asInt(pagination['limit']) ?? data.length,
      hasMore: asBool(pagination['hasMore']) ?? false,
    );
  }
}
