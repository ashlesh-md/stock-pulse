import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';

abstract final class ReadRetryPolicy {
  static Duration? delayFor(Result<Object?> result) => switch (result) {
    Failure(error: NetworkError()) => const Duration(seconds: 1),
    Failure(error: ServerError(:final statusCode)) when statusCode >= 500 =>
      const Duration(seconds: 1),
    Failure(error: ServerError(statusCode: 429, retryAfter: final delay?)) =>
      delay,
    Failure(error: ServerError(statusCode: 429)) => const Duration(seconds: 2),
    _ => null,
  };
}
