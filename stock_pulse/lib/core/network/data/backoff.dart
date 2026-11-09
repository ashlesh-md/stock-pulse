import 'dart:math';

/// Delay before reconnect attempt number [attempt] (0-based).
///
/// Exponential: 0.5s, 1s, 2s, 4s … capped at [max]. "Equal jitter" then
/// keeps half the delay and randomises the other half, so thousands of
/// phones that lost the same server do not all reconnect in the same
/// millisecond (the "thundering herd").
Duration reconnectDelay(
  int attempt, {
  Duration base = const Duration(milliseconds: 500),
  Duration max = const Duration(seconds: 30),
  Random? random,
}) {
  final exp = base.inMilliseconds * pow(2, attempt.clamp(0, 20));
  final capped = min(exp, max.inMilliseconds).toInt();
  final half = capped ~/ 2;
  return Duration(milliseconds: half + (random ?? Random()).nextInt(half + 1));
}
