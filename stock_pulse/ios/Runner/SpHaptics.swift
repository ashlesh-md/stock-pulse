import Flutter
import UIKit

/// Order-outcome haptics on channel `stockpulse/haptics` (FR-100).
/// `success` → `.success`, `rejection` → `.error`; always `result(nil)`.
/// Without a Taptic Engine the generator does nothing.
final class SpHaptics: NSObject {
  private let generator = UINotificationFeedbackGenerator()

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SpHaptics()
    let channel = FlutterMethodChannel(
      name: "stockpulse/haptics",
      binaryMessenger: registrar.messenger()
    )
    instance.generator.prepare()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "success":
      generator.notificationOccurred(.success)
      generator.prepare()
      result(nil)
    case "rejection":
      generator.notificationOccurred(.error)
      generator.prepare()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
