import 'package:stock_pulse/core/error/app_error.dart';

/// Return type of every repository call: [Success] with a value or [Failure]
/// with an [AppError]. Nothing in the data layer throws to the UI.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppError error;
}

extension ResultX<T> on Result<T> {
  /// Value or throw. Use inside a notifier's `build`, where a throw becomes
  /// `AsyncError` and the screen shows its error state.
  T getOrThrow() => switch (this) {
    Success(:final value) => value,
    Failure(:final error) => throw error,
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success(:final value) => Success(transform(value)),
    Failure(:final error) => Failure(error),
  };

  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };
}

/// Runs [parse] over decoded JSON. A missing field, a wrong type, a bad
/// date or an unknown enum name becomes a [ParseError] instead of a throw.
Result<T> parseJson<T>(T Function() parse) {
  try {
    return Success(parse());
  } on TypeError {
    return const Failure(ParseError());
  } on FormatException {
    return const Failure(ParseError());
  } on ArgumentError {
    return const Failure(ParseError());
  }
}
