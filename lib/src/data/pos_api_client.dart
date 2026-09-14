/// Dio-backed HTTP client for the `/pos/*` backend.
///
/// Ported from `pos-core/.../data/network/PosService.kt` (timeouts, JSON
/// body) and `pos-core/.../util/PosAuthInterceptor.kt` (bearer header,
/// per-request token read). This is the only file in the package that
/// imports `package:dio/dio.dart` directly — everything above `data/`
/// depends on [PosException], never on Dio.
library;

import 'package:dio/dio.dart';

import 'pos_exception.dart';

/// Connect/send/receive timeout, matching `PosService.TIMEOUT_SECONDS`.
const _timeout = Duration(seconds: 10);

/// Thin wrapper over [Dio] that:
///  * attaches `Authorization: Bearer <token>` from [tokenProvider] fresh on
///    every call (the host owns refresh; nothing here caches the token),
///  * merges in [extraHeaders] (the Dart counterpart of the device-id /
///    version-id / user-agent headers `PosAuthInterceptor` adds),
///  * decodes the backend's `{"response_code"/"code": ..., "message": ...,
///    "data": ...}` envelope by the same success predicate the pinned
///    Kotlin's `ResponseManager.responseImpl` applies (see [_decodeSuccess]),
///    and
///  * translates every `DioException` into a [PosException] so nothing
///    above `data/` ever sees Dio.
class PosApiClient {
  PosApiClient({
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
    Map<String, String> Function()? extraHeaders,
    Dio? dio,
  }) // The constructor parameters keep public names (`tokenProvider`,
    // `extraHeaders`) while the fields are private, so an initializing formal
    // (`this._tokenProvider`) isn't an option — that would make the named
    // parameter itself private and uncallable from other libraries.
    : _tokenProvider = tokenProvider, // ignore: prefer_initializing_formals
       _extraHeaders = extraHeaders, // ignore: prefer_initializing_formals
       _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = _timeout
      ..sendTimeout = _timeout
      ..receiveTimeout = _timeout
      // Request bodies are always JSON; without this Dio url-encodes a
      // `Map` body instead of JSON-encoding it (see
      // `Transformer.defaultTransformRequest`).
      ..contentType = Headers.jsonContentType;
  }

  final Dio _dio;
  final Future<String?> Function() _tokenProvider;
  final Map<String, String> Function()? _extraHeaders;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    // Read fresh on every call — never cached on the client.
    final token = await _tokenProvider();
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?_extraHeaders?.call(),
    };

    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        queryParameters: query,
        data: body,
        options: Options(method: method, headers: headers),
      );
    } on DioException catch (error) {
      throw _translate(error);
    }
    return _decodeSuccess(response);
  }

  /// A 2xx HTTP response reached here; still validates the backend's own
  /// business-level success code. The body's `status` field is **not** the
  /// success signal — `GeneralResponse.java` declares it as a separate,
  /// unrelated field. The real predicate, ported from
  /// `ResponseManager.responseImpl` (pinned Kotlin,
  /// `common-general/.../network/ResponseManager.kt:277-300`):
  ///  * the code comes from `response_code`, then `code`, then
  ///    `responseCode` (`GeneralResponse`'s `@SerializedName` alternates);
  ///    when none of those keys is present at all, it defaults to the HTTP
  ///    status code (`dataResponse.code = dataResponse.code ?: response.code()`).
  ///  * success iff the code's first two characters are a prefix of `"00"`,
  ///    or the full code is (case-insensitively) `"0P00"`, `"0P01"`,
  ///    `"200"`, or merely *contains* `"200"` — the last of those is
  ///    `PosRepositoryImpl.kt`'s `isSuccess = { code -> code.contains("200") }`,
  ///    passed for every `/pos/` call and folded in here.
  /// The failure message comes from `message`, then `msg`, then
  /// `responseMessage`.
  Map<String, dynamic> _decodeSuccess(Response<dynamic> response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw PosException(
        kind: PosErrorKind.badResponse,
        message: 'Unexpected response body',
        statusCode: response.statusCode,
      );
    }

    final code =
        data['response_code']?.toString() ??
        data['code']?.toString() ??
        data['responseCode']?.toString() ??
        response.statusCode?.toString() ??
        '';

    if (_isSuccessCode(code)) return data;

    final message =
        data['message']?.toString() ??
        data['msg']?.toString() ??
        data['responseMessage']?.toString() ??
        'Request failed';
    throw PosException(
      kind: PosErrorKind.unknown,
      message: message,
      code: code.isEmpty ? null : code,
      statusCode: response.statusCode,
    );
  }

  /// The `ResponseManager.responseImpl` / `PosRepositoryImpl.isSuccess`
  /// predicate described above [_decodeSuccess], applied case-insensitively.
  /// Kotlin's `responseCodeFull.substring(0, 2)` throws for a code shorter
  /// than two characters; here that case simply fails the `"00"`-prefix leg
  /// rather than throwing, then falls through to the other legs.
  bool _isSuccessCode(String code) {
    final full = code.toUpperCase();
    final prefix = full.length >= 2 ? full.substring(0, 2) : null;
    return (prefix != null && '00'.startsWith(prefix)) ||
        full == '0P00' ||
        full == '0P01' ||
        full == '200' ||
        full.contains('200');
  }

  PosException _translate(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return PosException(
          kind: PosErrorKind.timeout,
          message: 'Connection timed out',
          cause: error,
        );
      case DioExceptionType.cancel:
        return PosException(
          kind: PosErrorKind.cancelled,
          message: 'Request cancelled',
          cause: error,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return PosException(
          kind: PosErrorKind.network,
          message: error.message ?? 'Network error',
          cause: error,
        );
      case DioExceptionType.badResponse:
        return _translateBadResponse(error);
      case DioExceptionType.unknown:
        // Any non-Dio error thrown by the adapter or the JSON transformer
        // lands here (Dio wraps it with type `unknown`). A `FormatException`
        // means the body wasn't valid JSON; anything else is a lower-level
        // transport failure (e.g. a `SocketException`).
        if (error.error is FormatException) {
          return PosException(
            kind: PosErrorKind.badResponse,
            message: 'Malformed response body',
            statusCode: error.response?.statusCode,
            cause: error,
          );
        }
        return PosException(
          kind: PosErrorKind.network,
          message: error.message ?? 'Network error',
          cause: error,
        );
    }
  }

  PosException _translateBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;
    final body = error.response?.data;
    final backendMessage = body is Map ? body['message']?.toString() : null;
    final backendCode = body is Map
        ? (body['status']?.toString() ?? body['code']?.toString())
        : null;
    final message = backendMessage ?? error.message ?? 'Request failed';

    if (statusCode == 401) {
      return PosException(
        kind: PosErrorKind.unauthorized,
        message: message,
        code: backendCode,
        statusCode: statusCode,
        cause: error,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return PosException(
        kind: PosErrorKind.server,
        message: message,
        code: backendCode,
        statusCode: statusCode,
        cause: error,
      );
    }
    return PosException(
      kind: PosErrorKind.unknown,
      message: message,
      code: backendCode,
      statusCode: statusCode,
      cause: error,
    );
  }
}
