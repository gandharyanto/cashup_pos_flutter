/// Resolves a possibly-relative image path against a base URL.
///
/// The backend stores product/category photos as paths relative to a
/// per-tenant asset host (delivered separately as SDK config), not as full
/// URLs. [ImageThumb] (and anything else rendering a backend photo) goes
/// through this helper rather than string-concatenating locally, so the
/// slash-joining rule lives in exactly one place.
///
/// Returns `null` when either argument is missing — there is nothing useful
/// to resolve, and the caller is expected to fall back to a placeholder
/// rather than request a broken URL.
///
/// [relative] that is already absolute (has a URL scheme, e.g. `https://`)
/// is returned untouched: some backend responses already carry a full CDN
/// URL rather than a relative path.
String? resolveImageUrl(String? relative, String? baseUrl) {
  if (relative == null || relative.isEmpty) return null;
  if (baseUrl == null || baseUrl.isEmpty) return null;

  final parsed = Uri.tryParse(relative);
  if (parsed != null && parsed.hasScheme) return relative;

  final normalizedBase = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final normalizedRelative = relative.startsWith('/') ? relative : '/$relative';
  return '$normalizedBase$normalizedRelative';
}
