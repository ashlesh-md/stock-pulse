import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/core_api.dart';
import 'package:stock_pulse/core/network/data/read_retry_policy.dart';
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
    Future<void> Function(Duration delay)? wait,
  }) : _client = client ?? http.Client(),
       _wait = wait ?? _waitFor;

  final AppConfig _config;
  final http.Client _client;
  final Duration timeout;
  final Future<void> Function(Duration delay) _wait;

  Future<Result<Object?>> call(Endpoint endpoint) async {
    final first = await _send(_request(endpoint));
    if (endpoint.method != HttpMethod.get) return first;
    final delay = ReadRetryPolicy.delayFor(first);
    if (delay == null) return first;
    await _wait(delay);
    return _send(_request(endpoint));
  }

  http.Request _request(Endpoint endpoint) {
    final request = http.Request(
      endpoint.method.name.toUpperCase(),
      uriOf(endpoint),
    )..headers.addAll(endpoint.headers);
    if (endpoint.body case final Object body) {
      request
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    return request;
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
        retryAfter: res.statusCode == 429 ? _retryAfter(res.headers) : null,
      ),
    );
  }

  Duration? _retryAfter(Map<String, String> headers) {
    String? value;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'retry-after') {
        value = entry.value;
        break;
      }
    }
    if (value == null) return null;
    final seconds = int.tryParse(value);
    if (seconds != null) return Duration(seconds: seconds.clamp(0, 30));
    final retryAt = _parseHttpDate(value);
    if (retryAt != null) {
      final delay = retryAt.difference(DateTime.now().toUtc());
      return delay.isNegative ? Duration.zero : delay;
    }
    return null;
  }

  DateTime? _parseHttpDate(String value) {
    final match = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value);
    if (match == null) return null;
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final month = months[match[2]];
    if (month == null) return null;
    return DateTime.utc(
      int.parse(match[3]!),
      month,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6]!),
    );
  }

  static Future<void> _waitFor(Duration delay) => Future<void>.delayed(delay);
}
