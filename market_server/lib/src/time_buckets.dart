/// Indian Standard Time is UTC+05:30 all year (no daylight saving).
const istOffset = Duration(hours: 5, minutes: 30);

const _dayMs = 86400000;

/// Start (as a UTC instant) of the candle bucket [time] falls in.
///
/// Buckets are aligned to IST, the way Indian brokers draw charts:
/// - 1m / 5m / 15m: the 5h30m offset is a multiple of 15 minutes, so these
///   line up with plain UTC buckets too.
/// - 1h: starts on the IST hour (03:30 UTC = 09:00 IST).
/// - 1d: starts at IST midnight (18:30 UTC the day before).
/// - 1w: starts on Monday 00:00 IST.
///
/// The Flutter app has the same function, so a live tick lands in the same
/// candle the server would put it in.
DateTime bucketStart(DateTime time, Duration interval) {
  final off = istOffset.inMilliseconds;
  final ms = time.millisecondsSinceEpoch + off; // "IST wall clock" millis
  final int start;
  if (interval.inDays == 7) {
    // 1970-01-01 was a Thursday, so Monday is 3 days earlier.
    final days = ms ~/ _dayMs;
    start = ((days + 3) ~/ 7 * 7 - 3) * _dayMs;
  } else {
    final size = interval.inMilliseconds;
    start = ms ~/ size * size;
  }
  return DateTime.fromMillisecondsSinceEpoch(start - off, isUtc: true);
}
