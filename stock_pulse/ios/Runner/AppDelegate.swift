import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushPermission") {
      let channel = FlutterMethodChannel(name: "stock_pulse/push_permission", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "status":
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { result(self.permissionName(settings.authorizationStatus)) }
          }
        case "request":
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { result(granted ? "granted" : "denied") }
          }
        case "openSettings":
          guard let url = URL(string: UIApplication.openSettingsURLString) else { result(nil); return }
          UIApplication.shared.open(url) { _ in result(nil) }
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpHaptics") {
      SpHaptics.register(with: registrar)
    }
  }

  private func permissionName(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized, .provisional, .ephemeral: return "granted"
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unavailable"
    }
  }
}
