enum PushPermissionStatus { granted, denied, notDetermined, unavailable }

abstract interface class PushPermissionService {
  Future<PushPermissionStatus> status();
  Future<PushPermissionStatus> request();
  Future<void> openSettings();
}
