import 'package:flutter/services.dart';
import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';
import 'package:stock_pulse/core/platform/domain/haptics.dart';

/// Android/iOS: `stockpulse/haptics` channel, methods `success` and
/// `rejection`, no args. If the native side is missing or fails, it logs
/// `haptics_unavailable` once and becomes a no-op; it never throws.
class MethodChannelHaptics implements Haptics {
  MethodChannelHaptics(this._reporter);

  static const channel = MethodChannel('stockpulse/haptics');

  final CrashReporter _reporter;
  bool _unavailable = false;

  @override
  Future<void> success() => _invoke('success');

  @override
  Future<void> rejection() => _invoke('rejection');

  Future<void> _invoke(String method) async {
    if (_unavailable) return;
    try {
      await channel.invokeMethod<void>(method);
    } on MissingPluginException {
      _disable(method);
    } on PlatformException {
      _disable(method);
    }
  }

  void _disable(String method) {
    _unavailable = true;
    _reporter.log('haptics_unavailable', {'method': method});
  }
}
