import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/platform/data/noop_haptics.dart';
import 'package:stock_pulse/core/platform/di/platform_providers.dart';

import '../../helpers/fake_haptics.dart';

void main() {
  test('NoopHaptics (web/desktop) never throws', () async {
    const h = NoopHaptics();
    await expectLater(h.success(), completes);
    await expectLater(h.rejection(), completes);
  });

  test('hapticsProvider can be overridden with a fake', () async {
    final fake = FakeHaptics();
    final container = ProviderContainer(
      overrides: [hapticsProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(hapticsProvider).success();
    expect(fake.calls, ['success']);
  });
}
