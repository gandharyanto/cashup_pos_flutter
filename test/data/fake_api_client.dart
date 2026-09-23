import 'package:cashup_pos/src/data/pos_api_client.dart';

/// A [PosApiClient] test double that records the last call made and returns
/// a canned envelope keyed by request path.
///
/// One canned body per path is enough for [PosRepositoryImpl]'s tests: each
/// test exercises a single endpoint per repository call. `implements` (not
/// `extends`) is deliberate — [PosApiClient]'s constructor requires a live
/// `Dio`, and only its public `get`/`post`/`put`/`delete` surface needs a
/// fake, which is all `implements` from another library requires.
class FakeApiClient implements PosApiClient {
  FakeApiClient(this._responses);

  final Map<String, Map<String, dynamic>> _responses;

  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Object? lastBody;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    lastQuery = query;
    lastBody = null;
    return _responseFor(path);
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    lastMethod = 'POST';
    lastPath = path;
    lastQuery = null;
    lastBody = body;
    return _responseFor(path);
  }

  @override
  Future<Map<String, dynamic>> put(String path, {Object? body}) async {
    lastMethod = 'PUT';
    lastPath = path;
    lastQuery = null;
    lastBody = body;
    return _responseFor(path);
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    lastMethod = 'DELETE';
    lastPath = path;
    lastQuery = null;
    lastBody = null;
    return _responseFor(path);
  }

  Map<String, dynamic> _responseFor(String path) {
    final response = _responses[path];
    if (response == null) {
      throw StateError('FakeApiClient has no canned response for "$path"');
    }
    return response;
  }
}
