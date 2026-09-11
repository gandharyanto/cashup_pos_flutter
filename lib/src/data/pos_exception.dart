/// Typed error model for `data/`.
///
/// Everything above `data/` (state, ui) sees only [PosException] —
/// never a `DioException`. [PosApiClient] is the only place a
/// `DioException` is caught and translated.
library;

/// Broad categories of failure the UI needs to distinguish, mirroring the
/// branches `ResponseManager` and the OkHttp interceptor stack handle on the
/// Kotlin side.
enum PosErrorKind {
  /// No connectivity, DNS failure, connection refused, TLS failure.
  network,

  /// Connect/send/receive exceeded `PosService.TIMEOUT_SECONDS`.
  timeout,

  /// HTTP 401 — the JWT is missing, expired, or rejected.
  unauthorized,

  /// HTTP 5xx.
  server,

  /// A 2xx response whose body could not be parsed as the expected JSON
  /// envelope (not JSON at all, or not a JSON object).
  badResponse,

  /// The request was cancelled by the caller.
  cancelled,

  /// Anything else — including a 2xx HTTP response whose body carries a
  /// non-success `status` (a business-level failure the backend reports
  /// with an HTTP 200), and 4xx responses other than 401.
  unknown,
}

/// The error type every `PosRepository` method throws.
class PosException implements Exception {
  const PosException({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
    this.cause,
  });

  /// The broad category, for callers that branch on failure type (e.g. the
  /// checkout flow prompting "retry?" only on [PosErrorKind.network] /
  /// [PosErrorKind.timeout]).
  final PosErrorKind kind;

  /// The backend's own message where one was available, otherwise a short
  /// English description of the transport failure. Prefer
  /// [friendlyMessage] for anything shown to a cashier.
  final String message;

  /// The backend's own error/status code, when the response body carried
  /// one (e.g. `"400"`). Not the HTTP status code — see [statusCode].
  final String? code;

  /// The HTTP status code, when a response was received at all.
  final int? statusCode;

  /// The original error (typically a `DioException`), kept for logging.
  final Object? cause;

  /// Indonesian copy suitable for direct display — every page shows this
  /// rather than [message], which may be English transport detail.
  String get friendlyMessage {
    switch (kind) {
      case PosErrorKind.network:
        return 'Tidak ada koneksi internet. POS memerlukan koneksi aktif.';
      case PosErrorKind.timeout:
        return 'Koneksi terlalu lama merespons. Coba lagi.';
      case PosErrorKind.unauthorized:
        return 'Sesi berakhir. Silakan masuk kembali.';
      case PosErrorKind.server:
        return message.isEmpty
            ? 'Server sedang bermasalah. Coba lagi.'
            : message;
      case PosErrorKind.badResponse:
        return 'Respons server tidak dikenali.';
      case PosErrorKind.cancelled:
        return 'Permintaan dibatalkan.';
      case PosErrorKind.unknown:
        return message.isEmpty ? 'Terjadi kesalahan. Coba lagi.' : message;
    }
  }

  @override
  String toString() =>
      'PosException(kind: $kind, message: $message, code: $code, statusCode: $statusCode)';
}
