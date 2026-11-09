import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/push/data/noop_push_service.dart';

void main() {
  test('no-op push service returns no messages and empty streams', () async {
    const service = NoopPushService();
    await service.init();
    expect(await service.token(), isNull);
    expect(await service.initialMessage(), isNull);
    expect(await service.onTap.toList(), isEmpty);
    expect(await service.onForeground.toList(), isEmpty);
  });
}
