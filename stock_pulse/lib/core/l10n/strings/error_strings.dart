import 'package:stock_pulse/core/error/app_error.dart';

/// User text for failures. `AppError.message` is for logs only.
abstract interface class ErrorStrings {
  String get title;
  String get network;
  String get server;
  String get parse;

  /// A 404 on a known endpoint: the server predates this app.
  String get outdated;
  String get unknown;

  /// Debug builds only: how to start the local server.
  String get serverHint;
}

/// The text for [error], which may be any object an `AsyncError` holds.
String errorText(ErrorStrings strings, Object error) => switch (error) {
  NetworkError() => strings.network,
  ServerError(statusCode: 404) => strings.outdated,
  ServerError() => strings.server,
  ParseError() => strings.parse,
  _ => strings.unknown,
};
