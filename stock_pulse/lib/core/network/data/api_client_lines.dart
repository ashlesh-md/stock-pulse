import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/endpoint.dart';

extension ApiClientLines on ApiClient {
  /// Cancelling aborts the HTTP request, including a silent connection.
  Stream<Map<String, Object?>> postLines(String path, Object body) {
    final abort = Completer<void>();
    StreamSubscription<String>? subscription;
    var cancelled = false;
    final output = StreamController<Map<String, Object?>>();
    void abortRequest() {
      cancelled = true;
      if (!abort.isCompleted) abort.complete();
    }

    Future<void> start() async {
      try {
        final request =
            http.AbortableRequest(
                'POST',
                uriOf(Endpoint.post(path)),
                abortTrigger: abort.future,
              )
              ..headers['content-type'] = 'application/json'
              ..body = jsonEncode(body);
        final response = await send(request)
            .timeout(const Duration(seconds: 15));
        if (cancelled) return;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          abortRequest();
          output.addError(
            ServerError(
              response.statusCode,
              'http_${response.statusCode}',
              'Answer unavailable',
            ),
          );
          unawaited(output.close());
          return;
        }
        subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(const Duration(seconds: 15))
            .listen(
              (line) {
                if (line.trim().isEmpty) return;
                try {
                  final json = jsonDecode(line);
                  if (json is! Map<String, Object?>) {
                    throw const FormatException();
                  }
                  output.add(json);
                } on FormatException {
                  output.addError(const ParseError());
                  abortRequest();
                  unawaited(subscription?.cancel());
                  unawaited(output.close());
                }
              },
              onError: (Object error) {
                output.addError(
                  error is FormatException
                      ? const ParseError()
                      : const NetworkError(),
                );
                abortRequest();
                unawaited(subscription?.cancel());
                unawaited(output.close());
              },
              onDone: output.close,
            );
      } on Exception {
        if (!cancelled) {
          output.addError(const NetworkError());
          abortRequest();
          unawaited(output.close());
        }
      }
    }

    output
      ..onListen = (() => unawaited(start()))
      ..onCancel = () {
        abortRequest();
        return subscription?.cancel();
      }
      ..onPause = (() => subscription?.pause())
      ..onResume = (() => subscription?.resume());
    return output.stream;
  }
}
