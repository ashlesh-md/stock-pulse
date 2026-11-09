import 'package:stock_pulse/core/platform/domain/haptics.dart';

/// Used on web and desktop, which have no vibration motor.
class NoopHaptics implements Haptics {
  const NoopHaptics();

  @override
  Future<void> success() async {}

  @override
  Future<void> rejection() async {}
}
