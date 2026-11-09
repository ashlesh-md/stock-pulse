import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/push/data/platform_push_permission_service.dart';
import 'package:stock_pulse/core/push/domain/push_permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('stock_pulse/push_permission');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  String response = 'notDetermined';
  final calls = <String>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'openSettings') return null;
      return response;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('maps native status and invokes request/settings actions', () async {
    final service = PlatformPushPermissionService(channel: channel);
    expect(await service.status(), PushPermissionStatus.notDetermined);
    response = 'granted';
    expect(await service.request(), PushPermissionStatus.granted);
    await service.openSettings();
    expect(calls, ['status', 'request', 'openSettings']);
  });

  test('unknown native status fails closed as unavailable', () async {
    response = 'unexpected';
    expect(
      await PlatformPushPermissionService(channel: channel).status(),
      PushPermissionStatus.unavailable,
    );
  });

  test(
    'missing native implementation is unavailable without throwing',
    () async {
      messenger.setMockMethodCallHandler(channel, null);
      final service = PlatformPushPermissionService(channel: channel);
      expect(await service.status(), PushPermissionStatus.unavailable);
      expect(await service.request(), PushPermissionStatus.unavailable);
      await service.openSettings();
    },
  );

  test('platform failures are handled as unavailable/no-op', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    final service = PlatformPushPermissionService(channel: channel);
    expect(await service.status(), PushPermissionStatus.unavailable);
    expect(await service.request(), PushPermissionStatus.unavailable);
    await service.openSettings();
  });
}
