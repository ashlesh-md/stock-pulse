/// Every error the data layer can return. `sealed`, so a `switch` must
/// handle each case. [message] is for logs; user-facing text comes from
/// `AppStrings`.
sealed class AppError implements Exception {
  const AppError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// No connection, DNS failure, timeout: the request never got an answer.
final class NetworkError extends AppError {
  const NetworkError([super.message = 'Cannot reach the server']);
}

/// The server answered with an error body: `{"error": {"code", "message"}}`.
final class ServerError extends AppError {
  const ServerError(this.statusCode, this.code, super.message);
  final int statusCode;
  final String code;
}

/// The response was not the JSON we expected.
final class ParseError extends AppError {
  const ParseError([super.message = 'Unexpected response from the server']);
}
