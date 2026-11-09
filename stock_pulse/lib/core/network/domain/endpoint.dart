import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

enum HttpMethod { get, post, delete }

/// One REST call: method, path, query, JSON body and extra headers. Each
/// feature builds its endpoints in `data/<feature>_api.dart`, so no
/// repository writes a path string.
@immutable
class Endpoint {
  const Endpoint.get(this.path, {this.query = const {}})
    : method = HttpMethod.get,
      body = null,
      headers = const {};

  const Endpoint.post(this.path, {this.body, this.headers = const {}})
    : method = HttpMethod.post,
      query = const {};

  const Endpoint.delete(this.path)
    : method = HttpMethod.delete,
      query = const {},
      body = null,
      headers = const {};

  final HttpMethod method;
  final String path;
  final Map<String, String> query;

  /// Encoded as JSON; null sends no body.
  final Object? body;
  final Map<String, String> headers;

  static const _deep = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is Endpoint &&
      other.method == method &&
      other.path == path &&
      _deep.equals(other.query, query) &&
      _deep.equals(other.body, body) &&
      _deep.equals(other.headers, headers);

  @override
  int get hashCode => Object.hash(
    method,
    path,
    _deep.hash(query),
    _deep.hash(body),
    _deep.hash(headers),
  );

  @override
  String toString() => '${method.name.toUpperCase()} $path';
}
