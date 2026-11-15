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
  const ServerError(
    this.statusCode,
    this.code,
    super.message, {
    this.retryAfter,
  });
  final int statusCode;
  final String code;
  final Duration? retryAfter;
}

/// The response was not the JSON we expected.
final class ParseError extends AppError {
  const ParseError([super.message = 'Unexpected response from the server']);
}

/// A local read or write failed. The cached value remains usable where possible.
final class StorageError extends AppError {
  const StorageError([super.message = 'Local storage is unavailable']);
}
