/// Device time source. Injected so tests can move time.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Test clock: time moves only on [advance] / [set].
class FakeClock implements Clock {
  FakeClock(DateTime start) : _now = start;

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);

  void set(DateTime t) => _now = t;
}
