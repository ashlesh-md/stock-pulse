import 'dart:collection';

/// In-memory LRU of announced order outcomes. Keys are records such
/// as `(orderId, status)` or `(clientKey, 'rejected')`. Seeded from the first
/// `GET /orders` so a relaunch or resync never re-announces.
class HapticDedupe {
  HapticDedupe({this.capacity = 500}) : assert(capacity > 0);

  final int capacity;

  // LinkedHashSet keeps insertion order: first = least recently seen.
  final LinkedHashSet<Object> _seen = LinkedHashSet<Object>();

  int get length => _seen.length;

  /// True the first time [key] is seen; false after (and refreshes it).
  bool firstTime(Object key) {
    final known = _seen.remove(key);
    _seen.add(key);
    if (_seen.length > capacity) _seen.remove(_seen.first);
    return !known;
  }

  /// Marks keys as already announced.
  void seed(Iterable<Object> keys) {
    for (final k in keys) {
      firstTime(k);
    }
  }
}
