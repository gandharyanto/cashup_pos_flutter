/// Resolves a product image path against the metadata base url the backend
/// returns alongside the catalogue, since product/option images come back
/// as paths relative to that base rather than as full urls.
library;

/// Joins [relative] onto [baseUrl], or passes an already-absolute url
/// through untouched.
///
/// Returns `null` when either [relative] or [baseUrl] is missing, or when
/// [relative] is empty — there is nothing to resolve.
String? resolveImageUrl(String? relative, String? baseUrl) {
  if (relative == null || relative.isEmpty) return null;
  if (relative.startsWith('http://') || relative.startsWith('https://')) {
    return relative;
  }
  if (baseUrl == null || baseUrl.isEmpty) return null;

  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final path = relative.startsWith('/') ? relative : '/$relative';
  return '$base$path';
}
