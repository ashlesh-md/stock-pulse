# ADR-0012: `Result` is `Success` | `Failure`; the error hierarchy is renamed `AppError`

Status: accepted · Date: 2026-11-07 · Refs: CR-1.7; HLD v2.0 §10.2; `core/error/`

## Context
`core/error/result.dart` defines `sealed class Result<T>` with `Ok<T>(value)` and `Err<T>(failure)`; the error type is
`sealed class Failure` with `NetworkFailure`, `ServerFailure`, `ParseFailure`. The user finds `Ok` / `Err` poor names
(CR-1.7): they are abbreviations, `Err` reads like a typo, and `Err(:final failure)` mixes two words for one idea.
Usage today: 50 `Ok`, 59 `Err`, 38 `*Failure` references across `lib/` and `test/` (the server has no `Result`).

## Options
1. `Success` / `Failure` for the result, rename the error class to `AppError` (`NetworkError`, `ServerError`, `ParseError`).
2. `Success` / `Fail`, keep `Failure` as the error class. No clash, but `Fail` is a verb and `Fail(:final failure)` repeats.
3. `Result.success(...)` / `Result.failure(...)` factory constructors over private subclasses. Patterns need public
   subclass names anyway (`case _Success()` is not allowed outside the library), so it collapses into 1 or 2.
4. `Ok` / `Err` kept, documented. Rejected by the user.

## Decision
Option 1. The two outcomes are `Success` and `Failure` (the words Kotlin and Swift use for the same type), and the thing
inside a failure is an `AppError`. Each word means one thing.

```dart
// core/error/result.dart
sealed class Result<T> { const Result(); }
final class Success<T> extends Result<T> { const Success(this.value); final T value; }
final class Failure<T> extends Result<T> { const Failure(this.error); final AppError error; }

extension ResultX<T> on Result<T> {
  T getOrThrow() => switch (this) { Success(:final value) => value, Failure(:final error) => throw error };
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success(:final value) => Success(transform(value)), Failure(:final error) => Failure(error) };
  T? get valueOrNull => switch (this) { Success(:final value) => value, Failure() => null };
}

// core/error/app_error.dart
sealed class AppError implements Exception { const AppError(this.message); final String message; }
final class NetworkError extends AppError { ... }                       // no answer: DNS, timeout, refused
final class ServerError extends AppError { final int statusCode; final String code; ... }
final class ParseError extends AppError { ... }
```
Call sites read `case Success(:final value)` and `case Failure(:final error)`.

`AppError.message` is a developer message for logs. Text the user sees comes from `AppStrings` (ADR-0018): the application
layer maps an `AppError` to a `FeedbackMessage` or a state field, never shows `message` raw.

**Migration** (one mechanical change, refactor story R-1a, dev-realtime, while others are stopped):
1. Rename in this order with the IDE's rename (or `sed` with word boundaries): `Failure` → `AppError`, `NetworkFailure` →
   `NetworkError`, `ServerFailure` → `ServerError`, `ParseFailure` → `ParseError`, file `failure.dart` → `app_error.dart`.
   Do this first, so the name `Failure` is free.
2. `Ok` → `Success`, `Err` → `Failure`; the field `failure` on the failure case → `error` (`Err(:final failure)` →
   `Failure(:final error)`).
3. Add `valueOrNull`; keep `getOrThrow`, `map`.
4. `flutter analyze` and `flutter test` green; grep `\bOk(\|\bErr(\|NetworkFailure` returns nothing.

## Consequences
- 155 references change, all mechanical, in one story. Every LLD and §10.2 now say `Success` / `Failure` / `AppError`.
- `Failure` is now a `Result` case, not an exception: code that did `throw failure` now throws `error` (an `AppError`).
  `AsyncError.error` in controllers is therefore an `AppError`; screens and tests match on `AppError` subclasses.
- No clash with Flutter or Dart SDK names (`FlutterError`, `AsyncError`, `Error` are different identifiers).
