import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/push/data/noop_push_service.dart';
import 'package:stock_pulse/core/push/data/platform_push_permission_service.dart';
import 'package:stock_pulse/core/push/domain/push_permission_service.dart';
import 'package:stock_pulse/core/push/domain/push_service.dart';

final pushServiceProvider = Provider<PushService>(
  (ref) => const NoopPushService(),
);

final pushPermissionServiceProvider = Provider<PushPermissionService>(
  (ref) => PlatformPushPermissionService(),
);
