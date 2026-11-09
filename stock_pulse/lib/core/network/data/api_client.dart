import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/core_api.dart';
import 'package:stock_pulse/core/network/domain/endpoint.dart';

/// Thin wrapper over `package:http` for the REST API.
///
/// It adds the auth header and a timeout, decodes JSON, and turns every
/// problem into an [AppError], so repositories only map JSON to models.
class ApiClient {
  ApiClient(
    this._config, {
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final AppConfig _config;
  final http.Client _client;
  final Duration timeout;

  Future<Result<Object?>> call(Endpoint endpoint) {
    final request = http.Request(
      endpoint.method.name.toUpperCase(),
      uriOf(endpoint),
    )..headers.addAll(endpoint.headers);
    if (endpoint.body case final Object body) {
      request
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    return _send(request);
  }

  /// The one place that adds the auth header. [req] has its full URL
  /// already (see [uriOf]). No timeout here: streaming callers manage their
  /// own. Never logs headers or bodies.
  Future<http.StreamedResponse> send(http.BaseRequest req) {
    req.headers['authorization'] = 'Bearer ${_config.token}';
    return _client.send(req);
  }

  Uri uriOf(Endpoint endpoint) => _config.restBase.replace(
    path: endpoint.path,
    queryParameters: endpoint.query.isEmpty ? null : endpoint.query,
  );

  /// `GET /health` with a short timeout, for the offline probe.
  Future<Result<void>> getHealth({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final res = await send(http.Request('GET', uriOf(healthEndpoint)))
          .timeout(timeout);
      await res.stream.drain<void>();
      return res.statusCode == 200
          ? const Success(null)
          : Failure(
              ServerError(
                res.statusCode,
                'http_${res.statusCode}',
                'Health check failed',
              ),
            );
    } on TimeoutException {
      return const Failure(NetworkError('The server took too long to answer'));
    } on Exception catch (e) {
      return Failure(NetworkError('Cannot reach the server ($e)'));
    }
  }

  void close() => _client.close();

  Future<Result<Object?>> _send(http.BaseRequest request) async {
    final http.Response res;
    try {
      res = await send(request).then(http.Response.fromStream).timeout(timeout);
    } on TimeoutException {
      return const Failure(NetworkError('The server took too long to answer'));
    } on http.ClientException catch (e) {
      return Failure(NetworkError('Cannot reach the server (${e.message})'));
    } on Exception catch (e) {
      // e.g. SocketException "Connection reset by peer" while reading the
      // response: still a network problem, never a crash.
      return Failure(NetworkError('Connection lost ($e)'));
    }

    final Object? body;
    try {
      // Decode bytes as UTF-8 ourselves: `res.body` falls back to Latin-1
      // when the server omits `charset`, which garbles ₹ and –.
      body = res.bodyBytes.isEmpty
          ? null
          : jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      return const Failure(ParseError()); // also bad UTF-8
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return Success(body);

    final error = body is Map ? body['error'] : null;
    return Failure(
      ServerError(
        res.statusCode,
        error is Map ? '${error['code']}' : 'http_${res.statusCode}',
        error is Map
            ? '${error['message']}'
            : 'Request failed (${res.statusCode})',
      ),
    );
  }
}
