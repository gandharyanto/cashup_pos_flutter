import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cashup_pos/src/data/pos_api_client.dart';
import 'package:cashup_pos/src/data/pos_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Handler = Future<ResponseBody> Function(
  RequestOptions options,
  Stream<Uint8List>? requestStream,
);

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);
  final _Handler handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options, requestStream);
}

/// Consolidates a request body stream into the string Dio sent on the wire.
Future<String> _readBody(Stream<Uint8List>? stream) async {
  if (stream == null) return '';
  final bytes = <int>[];
  await for (final chunk in stream) {
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}

void main() {
  late Dio dio;

  PosApiClient clientWith(
    _Handler handler, {
    Future<String?> Function()? tokenProvider,
    Map<String, String> Function()? extraHeaders,
  }) {
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/'));
    dio.httpClientAdapter = _StubAdapter(handler);
    return PosApiClient(
      baseUrl: 'https://example.test/',
      tokenProvider: tokenProvider ?? () async => 'token-123',
      extraHeaders: extraHeaders,
      dio: dio,
    );
  }

  /// A bare 2xx envelope with no `response_code`/`code`/`responseCode` key —
  /// success falls back to the HTTP status code alone.
  Future<ResponseBody> okBody([String body = '{"data":{}}']) async =>
      ResponseBody.fromString(
        body,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  test('attaches the bearer token from the provider on every call', () async {
    late RequestOptions seen;
    final client = clientWith((options, _) async {
      seen = options;
      return okBody();
    });

    await client.get('pos/category/list');
    expect(seen.headers['Authorization'], 'Bearer token-123');
  });

  test('translates a 401 into an unauthorized PosException', () async {
    final client = clientWith(
      (options, _) async => ResponseBody.fromString(
        '{"message":"token expired"}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    expect(
      () => client.get('pos/category/list'),
      throwsA(
        isA<PosException>()
            .having((e) => e.kind, 'kind', PosErrorKind.unauthorized)
            .having((e) => e.message, 'message', 'token expired'),
      ),
    );
  });

  test('translates a connection timeout into a timeout PosException', () async {
    final client = clientWith(
      (options, _) async => throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 10),
        requestOptions: options,
      ),
    );

    expect(
      () => client.get('pos/category/list'),
      throwsA(
        isA<PosException>().having((e) => e.kind, 'kind', PosErrorKind.timeout),
      ),
    );
  });

  // ── Success-code predicate (ResponseManager.responseImpl, pinned Kotlin:
  //    common-general/.../network/ResponseManager.kt:277-303 and
  //    GeneralResponse.java). `status` is never consulted. ────────────────

  test('a body with no code key succeeds on a 2xx HTTP status', () async {
    final client = clientWith((options, _) async => okBody('{"data":{}}'));
    await expectLater(client.get('pos/category/list'), completes);
  });

  test('`status` in the body is ignored — a bare {"status":"400"} still succeeds on HTTP 200', () async {
    final client = clientWith((options, _) async => okBody('{"status":"400"}'));
    await expectLater(client.get('pos/category/list'), completes);
  });

  for (final code in ['00', '0P01', '200']) {
    test('a body code of "$code" succeeds', () async {
      final client = clientWith(
        (options, _) async => okBody('{"code":"$code"}'),
      );
      await expectLater(client.get('pos/category/list'), completes);
    });
  }

  test('response_code "05" fails with the body message, code read from response_code', () async {
    final client = clientWith(
      (options, _) async => okBody('{"response_code":"05","message":"x"}'),
    );

    expect(
      () => client.get('pos/category/list'),
      throwsA(
        isA<PosException>()
            .having((e) => e.kind, 'kind', PosErrorKind.unknown)
            .having((e) => e.message, 'message', 'x')
            .having((e) => e.code, 'code', '05'),
      ),
    );
  });

  test(
    'the `msg` alternate is used as the message when `message` is absent',
    () async {
      final client = clientWith(
        (options, _) async =>
            okBody('{"response_code":"05","msg":"pakai msg"}'),
      );

      expect(
        () => client.get('pos/category/list'),
        throwsA(
          isA<PosException>().having((e) => e.message, 'message', 'pakai msg'),
        ),
      );
    },
  );

  test('a body code that is shorter than 2 characters does not match the "00" prefix rule', () async {
    final client = clientWith((options, _) async => okBody('{"code":"5"}'));

    expect(
      () => client.get('pos/category/list'),
      throwsA(
        isA<PosException>().having((e) => e.kind, 'kind', PosErrorKind.unknown),
      ),
    );
  });

  test('a body code that starts with 200 (contains rule) succeeds', () async {
    final client = clientWith((options, _) async => okBody('{"code":"20099"}'));
    await expectLater(client.get('pos/category/list'), completes);
  });

  test(
    'a malformed (non-JSON) body raises a badResponse PosException',
    () async {
      final client = clientWith(
        (options, _) async => ResponseBody.fromString(
          'not json at all',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

      expect(
        () => client.get('pos/category/list'),
        throwsA(
          isA<PosException>().having(
            (e) => e.kind,
            'kind',
            PosErrorKind.badResponse,
          ),
        ),
      );
    },
  );

  test('a body that decodes to something other than a JSON object raises badResponse', () async {
    final client = clientWith(
      (options, _) async => ResponseBody.fromString(
        '[1,2,3]',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    expect(
      () => client.get('pos/category/list'),
      throwsA(
        isA<PosException>().having(
          (e) => e.kind,
          'kind',
          PosErrorKind.badResponse,
        ),
      ),
    );
  });

  test('a transport-level failure raises a network PosException', () async {
    final client = clientWith(
      (options, _) async => throw const SocketException('Failed host lookup'),
    );

    expect(
      () => client.get('pos/category/list'),
      throwsA(
        isA<PosException>().having((e) => e.kind, 'kind', PosErrorKind.network),
      ),
    );
  });

  test('a cancelled request raises a cancelled PosException', () async {
    final client = clientWith(
      (options, _) async => throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'user cancelled',
      ),
    );

    expect(
      () => client.get('pos/category/list'),
      throwsA(
        isA<PosException>().having(
          (e) => e.kind,
          'kind',
          PosErrorKind.cancelled,
        ),
      ),
    );
  });

  test(
    'a 5xx response raises a server PosException carrying the backend message',
    () async {
      final client = clientWith(
        (options, _) async => ResponseBody.fromString(
          '{"message":"Terjadi kesalahan pada server"}',
          500,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

      expect(
        () => client.get('pos/category/list'),
        throwsA(
          isA<PosException>()
              .having((e) => e.kind, 'kind', PosErrorKind.server)
              .having(
                (e) => e.message,
                'message',
                'Terjadi kesalahan pada server',
              ),
        ),
      );
    },
  );

  test('connect, send and receive timeouts are configured at 10 seconds', () {
    clientWith((options, _) async => okBody());

    expect(dio.options.connectTimeout, const Duration(seconds: 10));
    expect(dio.options.sendTimeout, const Duration(seconds: 10));
    expect(dio.options.receiveTimeout, const Duration(seconds: 10));
  });

  test('the token is read fresh on every request rather than cached', () async {
    var callCount = 0;
    final headersSeen = <String?>[];
    final client = clientWith(
      (options, _) async {
        headersSeen.add(options.headers['Authorization'] as String?);
        return okBody();
      },
      tokenProvider: () async {
        callCount++;
        return 'token-$callCount';
      },
    );

    await client.get('pos/category/list');
    await client.get('pos/category/list');

    expect(callCount, 2);
    expect(headersSeen, ['Bearer token-1', 'Bearer token-2']);
  });

  test(
    'extra headers from the callback are merged onto every request',
    () async {
      late RequestOptions seen;
      final client = clientWith((options, _) async {
        seen = options;
        return okBody();
      }, extraHeaders: () => {'device-id': 'device-abc', 'version-id': '42'});

      await client.get('pos/category/list');
      expect(seen.headers['device-id'], 'device-abc');
      expect(seen.headers['version-id'], '42');
    },
  );

  test('a POST body is sent JSON-encoded with a JSON content-type', () async {
    late String contentType;
    late String bodyText;
    final client = clientWith((options, requestStream) async {
      contentType = options.contentType ?? '';
      bodyText = await _readBody(requestStream);
      return okBody();
    });

    await client.post('pos/transaction/create', body: {'sku': 'ABC123'});

    expect(contentType, startsWith('application/json'));
    expect(jsonDecode(bodyText), {'sku': 'ABC123'});
  });

  test('a PUT body is sent JSON-encoded with a JSON content-type', () async {
    late String contentType;
    late String bodyText;
    final client = clientWith((options, requestStream) async {
      contentType = options.contentType ?? '';
      bodyText = await _readBody(requestStream);
      return okBody();
    });

    await client.put('pos/category/update', body: {'name': 'Minuman'});

    expect(contentType, startsWith('application/json'));
    expect(jsonDecode(bodyText), {'name': 'Minuman'});
  });
}
