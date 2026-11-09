import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/data/debug_crash_reporter.dart';

import '../../helpers/fake_crash_reporter.dart';

class _Throws extends StatelessWidget {
  const _Throws();

  @override
  Widget build(BuildContext context) => throw StateError('boom in build');
}

void main() {
  testWidgets('a throw in build is recorded once, not fatal', (tester) async {
    final fake = FakeCrashReporter();
    final savedFlutter = FlutterError.onError;
    final savedPresent = FlutterError.presentError;
    FlutterError.presentError = (_) {}; // keep the test output quiet
    installCrashHooks(fake);
    addTearDown(() {
      FlutterError.onError = savedFlutter;
      FlutterError.presentError = savedPresent;
      PlatformDispatcher.instance.onError = null;
    });

    await tester.pumpWidget(const _Throws());
    FlutterError.onError = savedFlutter; // before the test binding checks it

    expect(fake.errors, hasLength(1));
    expect(fake.errors.single.fatal, isFalse);
    expect(fake.errors.single.reason, 'flutter');
    expect(fake.errors.single.error, isA<StateError>());
  });

  test('an uncaught async error is recorded once as fatal and handled', () {
    final fake = FakeCrashReporter();
    final savedFlutter = FlutterError.onError;
    installCrashHooks(fake);
    addTearDown(() {
      FlutterError.onError = savedFlutter;
      PlatformDispatcher.instance.onError = null;
    });

    final handled = PlatformDispatcher.instance.onError!(
      StateError('async'),
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(fake.errors, hasLength(1));
    expect(fake.errors.single.fatal, isTrue);
  });

  test('DebugCrashReporter keeps the last 100 entries', () {
    final r = DebugCrashReporter(printer: (_) {});
    for (var i = 0; i < 105; i++) {
      r.log('e$i');
    }
    r.recordError(StateError('x'), StackTrace.empty, fatal: true);
    expect(r.entries, hasLength(DebugCrashReporter.capacity));
    expect(r.entries.first, contains('e6'));
    expect(r.entries.last, contains('fatal'));
  });
}
