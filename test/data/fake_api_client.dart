import 'package:cashup_pos/src/data/pos_api_client.dart';

/// Fake [PosApiClient] for repository tests.
///
/// Dart's implicit interfaces let this `implement` [PosApiClient] without
/// providing its private fields or constructor — only the four public
/// methods need bodies. It records the last call made (path, query, body)
/// and returns the canned envelope registered for that path, exactly as
/// [PosApiClient] would after already unwrapping and validating the
/// response — repository tests don't need to re-exercise that validation.
class FakeApiClient implements PosApiClient {
  FakeApiClient(this._responses);

  final Map<String, Map<String, dynamic>> _responses;

  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Object? lastBody;

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    lastMethod = 'GET';
    lastPath = path;
    lastQuery = query;
    return _respond(path);
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = body;
    return _respond(path);
  }

  @override
  Future<Map<String, dynamic>> put(String path, {Object? body}) {
    lastMethod = 'PUT';
    lastPath = path;
    lastBody = body;
    return _respond(path);
  }

  @override
  Future<Map<String, dynamic>> delete(String path) {
    lastMethod = 'DELETE';
    lastPath = path;
    return _respond(path);
  }

  Future<Map<String, dynamic>> _respond(String path) async {
    final body = _responses[path];
    if (body == null) {
      throw StateError('FakeApiClient: no canned response for "$path"');
    }
    return body;
  }
}
