import 'dart:convert';

/// Text of one WebSocket frame; binary frames are UTF-8.
String frameText(Object? data) =>
    data is String ? data : utf8.decode(data! as List<int>);

/// The frame as a JSON object, or null when it is not one. A bad frame is
/// dropped rather than closing the connection.
Map<String, Object?>? decodeFrame(String text) {
  try {
    return switch (jsonDecode(text)) {
      final Map<String, Object?> map => map,
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

/// Counts frames the socket had to drop and logs the first of each kind,
/// so a server sending garbage is visible without flooding the log.
class FrameDropCounter {
  FrameDropCounter(this._log);

  /// `CrashReporter.log`.
  final void Function(String event, Map<String, Object?> data) _log;
  final _logged = <String>{};
  int _count = 0;

  int get count => _count;

  void drop(String reason) {
    _count++;
    if (_logged.add(reason)) {
      _log('socket_frame_dropped', {'reason': reason});
    }
  }
}

/// Finds lost data frames: every data frame of one connection carries the
/// next `seq`, so a jump means the client missed something.
class SequenceGapDetector {
  int? _last;

  /// A new connection starts its own sequence.
  void reset() => _last = null;

  /// Records [seq] and says whether frames were skipped before it.
  bool isGap(Object? seq) {
    if (seq is! int) return false;
    final last = _last;
    _last = seq;
    return last != null && seq != last + 1;
  }
}
