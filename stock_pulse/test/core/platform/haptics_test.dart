import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/platform/data/method_channel_haptics.dart';
import 'package:stock_pulse/core/platform/data/noop_haptics.dart';
import 'package:stock_pulse/core/platform/di/platform_providers.dart';
import 'package:stock_pulse/core/platform/domain/haptic_dedupe.dart';

import '../../helpers/fake_crash_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stockpulse/haptics');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('MethodChannelHaptics (FR-100, FR-101, FR-126)', () {
    test('success and rejection reach the handler with no args', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      final reporter = FakeCrashReporter();
      final haptics = MethodChannelHaptics(reporter);

      await haptics.success();
      await haptics.rejection();

      expect(calls.map((c) => c.method), ['success', 'rejection']);
      expect(calls.every((c) => c.arguments == null), isTrue);
      expect(reporter.logs, isEmpty);
    });

    test('MissingPluginException: no throw, one log, then no-op', () async {
      // No mock handler → MissingPluginException from the channel.
      final reporter = FakeCrashReporter();
      final haptics = MethodChannelHaptics(reporter);

      await expectLater(haptics.success(), completes);
      await expectLater(haptics.rejection(), completes);
      await expectLater(haptics.success(), completes);

      expect(reporter.logsNamed('haptics_unavailable'), hasLength(1));
    });

    test(
      'PlatformException: no throw, one log, later calls skip the channel',
      () async {
        var hits = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          hits++;
          throw PlatformException(code: 'no_vibrator');
        });
        final reporter = FakeCrashReporter();
        final haptics = MethodChannelHaptics(reporter);

        await expectLater(haptics.rejection(), completes);
        await expectLater(haptics.success(), completes);

        expect(hits, 1);
        expect(reporter.logsNamed('haptics_unavailable'), hasLength(1));
      },
    );
  });

  group('hapticsProvider platform choice', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    for (final p in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.fuchsia,
    ]) {
      test('$p → MethodChannelHaptics', () {
        debugDefaultTargetPlatformOverride = p;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        expect(container().read(hapticsProvider), isA<MethodChannelHaptics>());
      });
    }

    for (final p in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      test('$p → NoopHaptics', () {
        debugDefaultTargetPlatformOverride = p;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        expect(container().read(hapticsProvider), isA<NoopHaptics>());
      });
    }
  });

  group('HapticDedupe (NFR-10)', () {
    test('firstTime is true once per key', () {
      final d = HapticDedupe();
      expect(d.firstTime(('o1', 'filled')), isTrue);
      expect(d.firstTime(('o1', 'filled')), isFalse);
      expect(d.firstTime(('o1', 'rejected')), isTrue);
    });

    test('seeded keys are never announced', () {
      final d = HapticDedupe()..seed([('o1', 'filled'), ('o2', 'rejected')]);
      expect(d.firstTime(('o1', 'filled')), isFalse);
      expect(d.firstTime(('o2', 'rejected')), isFalse);
      expect(d.firstTime(('o3', 'filled')), isTrue);
    });

    test('keeps at most capacity keys, evicting the oldest', () {
      final d = HapticDedupe(capacity: 3);
      for (final k in ['a', 'b', 'c']) {
        d.firstTime(k);
      }
      d.firstTime('a'); // refreshes a; b is now oldest
      d.firstTime('d'); // evicts b
      expect(d.length, 3);
      expect(d.firstTime('b'), isTrue);
      expect(d.firstTime('a'), isFalse);
    });

    test('default capacity is 500', () {
      expect(HapticDedupe().capacity, 500);
    });
  });
}
