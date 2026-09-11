import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cashup_pos/src/data/pos_api_client.dart';
import 'package:cashup_pos/src/data/pos_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
}

void main() {
  late Dio dio;

  PosApiClient clientWith(
    Future<ResponseBody> Function(RequestOptions) handler, {
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

  test('attaches the bearer token from the provider on every call', () async {
    late RequestOptions seen;
    final client = clientWith((options) async {
      seen = options;
      return ResponseBody.fromString(
        '{"status":"200","data":{}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await client.get('pos/category/list');
    expect(seen.headers['Authorization'], 'Bearer token-123');
  });

  test('translates a 401 into an unauthorized PosException', () async {
    final client = clientWith(
      (options) async => ResponseBody.fromString(
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
      (options) async => throw DioException.connectionTimeout(
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

  test(
    'a non-success body status raises a PosException with the backend message',
    () async {
      final client = clientWith(
        (options) async => ResponseBody.fromString(
          '{"status":"400","message":"Stok tidak mencukupi","data":null}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

      expect(
        () => client.post('pos/transaction/create', body: {'foo': 'bar'}),
        throwsA(
          isA<PosException>()
              .having((e) => e.kind, 'kind', PosErrorKind.unknown)
              .having((e) => e.message, 'message', 'Stok tidak mencukupi')
              .having((e) => e.code, 'code', '400'),
        ),
      );
    },
  );

  test(
    'a malformed (non-JSON) body raises a badResponse PosException',
    () async {
      final client = clientWith(
        (options) async => ResponseBody.fromString(
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
      (options) async => ResponseBody.fromString(
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
      (options) async => throw const SocketException('Failed host lookup'),
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
      (options) async => throw DioException.requestCancelled(
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
        (options) async => ResponseBody.fromString(
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
    clientWith(
      (options) async =>
          ResponseBody.fromString('{"status":"200","data":{}}', 200),
    );

    expect(dio.options.connectTimeout, const Duration(seconds: 10));
    expect(dio.options.sendTimeout, const Duration(seconds: 10));
    expect(dio.options.receiveTimeout, const Duration(seconds: 10));
  });

  test('the token is read fresh on every request rather than cached', () async {
    var callCount = 0;
    final headersSeen = <String?>[];
    final client = clientWith(
      (options) async {
        headersSeen.add(options.headers['Authorization'] as String?);
        return ResponseBody.fromString(
          '{"status":"200","data":{}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
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
      final client = clientWith((options) async {
        seen = options;
        return ResponseBody.fromString(
          '{"status":"200","data":{}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }, extraHeaders: () => {'device-id': 'device-abc', 'version-id': '42'});

      await client.get('pos/category/list');
      expect(seen.headers['device-id'], 'device-abc');
      expect(seen.headers['version-id'], '42');
    },
  );
}
