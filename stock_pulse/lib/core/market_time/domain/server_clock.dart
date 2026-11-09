import 'package:stock_pulse/core/market_time/domain/clock.dart';

/// Server wall time estimated on the device: device time + offset.
///
/// The offset comes from `welcome.serverTime` and is refined by pongs: of the
/// last 5 samples, the one with the lowest round trip wins (its half-RTT
/// error is smallest). Freshness is computed in server time, so a device
/// clock that is 30 s off does not make live data look stale.
class ServerClock {
  ServerClock(this._device);

  static const _maxSamples = 5;

  final Clock _device;
  final List<({int rttMs, int offsetMs})> _samples = [];
  Duration _offset = Duration.zero;
  bool _synced = false;

  DateTime now() => _device.now().add(_offset);

  Duration get offset => _offset;

  /// True after the first `welcome`.
  bool get synced => _synced;

  void onWelcome(int serverTimeMs, DateTime receivedAt) {
    _samples.clear();
    _offset = Duration(
      milliseconds: serverTimeMs - receivedAt.millisecondsSinceEpoch,
    );
    _synced = true;
  }

  void onPong(int sentTsMs, int serverTimeMs, DateTime receivedAt) {
    final received = receivedAt.millisecondsSinceEpoch;
    final rtt = received - sentTsMs;
    if (rtt < 0) return; // device clock stepped back mid-ping
    _samples.add((rttMs: rtt, offsetMs: serverTimeMs + rtt ~/ 2 - received));
    if (_samples.length > _maxSamples) _samples.removeAt(0);
    var best = _samples.first;
    for (final s in _samples) {
      if (s.rttMs < best.rttMs) best = s;
    }
    _offset = Duration(milliseconds: best.offsetMs);
  }
}
