import Flutter
import UIKit
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up haptic feedback channel
    let controller = window?.rootViewController as! FlutterViewController
    let hapticChannel = FlutterMethodChannel(name: "bwgrid/haptics", binaryMessenger: controller.binaryMessenger)
    hapticChannel.setMethodCallHandler { (call, result) in
      self.handleHapticMethod(call: call, result: result)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleHapticMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "impact":
      if let args = call.arguments as? [String: Any],
         let style = args["style"] as? String,
         let intensity = args["intensity"] as? Double {
        self.performImpactFeedback(style: style, intensity: intensity)
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for impact", details: nil))
      }
    case "notification":
      if let args = call.arguments as? [String: Any],
         let type = args["type"] as? String {
        self.performNotificationFeedback(type: type)
        result(nil)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for notification", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func performImpactFeedback(style: String, intensity: Double) {
    let feedbackGenerator: UIImpactFeedbackGenerator
    switch style {
    case "light":
      feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    case "medium":
      feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    case "heavy":
      feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    case "rigid":
      if #available(iOS 13.0, *) {
        feedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
      } else {
        feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
      }
    case "soft":
      if #available(iOS 13.0, *) {
        feedbackGenerator = UIImpactFeedbackGenerator(style: .soft)
      } else {
        feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
      }
    default:
      feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    }
    feedbackGenerator.impactOccurred(intensity: CGFloat(intensity))
  }

  private func performNotificationFeedback(type: String) {
    let feedbackGenerator = UINotificationFeedbackGenerator()
    switch type {
    case "success":
      feedbackGenerator.notificationOccurred(.success)
    case "warning":
      feedbackGenerator.notificationOccurred(.warning)
    case "error":
      feedbackGenerator.notificationOccurred(.error)
    default:
      feedbackGenerator.notificationOccurred(.success)
    }
  }
}
