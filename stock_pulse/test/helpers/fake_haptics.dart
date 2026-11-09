import 'package:stock_pulse/core/platform/domain/haptics.dart';

/// Records every haptic call. Override `hapticsProvider` with it.
class FakeHaptics implements Haptics {
  final calls = <String>[];

  @override
  Future<void> success() async => calls.add('success');

  @override
  Future<void> rejection() async => calls.add('rejection');
}
