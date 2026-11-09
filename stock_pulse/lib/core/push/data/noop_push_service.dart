import 'package:stock_pulse/core/push/domain/push_service.dart';

class NoopPushService implements PushService {
  const NoopPushService();
  @override
  Future<void> init() async {}
  @override
  Future<String?> token() async => null;
  @override
  Future<PushMessage?> initialMessage() async => null;
  @override
  Stream<PushMessage> get onTap => const Stream.empty();
  @override
  Stream<PushMessage> get onForeground => const Stream.empty();
}
