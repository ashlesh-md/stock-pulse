import 'package:flutter/services.dart';
import 'package:stock_pulse/core/push/domain/push_permission_service.dart';

class PlatformPushPermissionService implements PushPermissionService {
  PlatformPushPermissionService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('stock_pulse/push_permission');

  final MethodChannel _channel;

  @override
  Future<PushPermissionStatus> status() async {
    try {
      return _parse(await _channel.invokeMethod<String>('status'));
    } on MissingPluginException {
      return PushPermissionStatus.unavailable;
    } on PlatformException {
      return PushPermissionStatus.unavailable;
    }
  }

  @override
  Future<PushPermissionStatus> request() async {
    try {
      return _parse(await _channel.invokeMethod<String>('request'));
    } on MissingPluginException {
      return PushPermissionStatus.unavailable;
    } on PlatformException {
      return PushPermissionStatus.unavailable;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  PushPermissionStatus _parse(String? value) => switch (value) {
    'granted' => PushPermissionStatus.granted,
    'denied' => PushPermissionStatus.denied,
    'notDetermined' => PushPermissionStatus.notDetermined,
    _ => PushPermissionStatus.unavailable,
  };
}
