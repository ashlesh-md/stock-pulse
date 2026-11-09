import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/platform/data/method_channel_haptics.dart';
import 'package:stock_pulse/core/platform/data/noop_haptics.dart';
import 'package:stock_pulse/core/platform/domain/haptics.dart';

/// `NoopHaptics` on web, macOS, Windows and Linux; the channel elsewhere.
final hapticsProvider = Provider<Haptics>((ref) {
  if (kIsWeb || !_hasVibration(defaultTargetPlatform)) {
    return const NoopHaptics();
  }
  return MethodChannelHaptics(ref.read(crashReporterProvider));
});

bool _hasVibration(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.fuchsia => true,
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => false,
};
