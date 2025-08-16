import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
      let hapticsChannel = FlutterMethodChannel(name: "bwgrid/haptics",
                                                binaryMessenger: controller.binaryMessenger)
      hapticsChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        guard call.method == "impact" else {
          result(FlutterMethodNotImplemented)
          return
        }
        if let args = call.arguments as? [String: Any],
           let styleStr = args["style"] as? String,
           let intensity = args["intensity"] as? Double {
          let generator: UIImpactFeedbackGenerator
          switch styleStr.lowercased() {
          case "light": generator = UIImpactFeedbackGenerator(style: .light)
          case "medium": generator = UIImpactFeedbackGenerator(style: .medium)
          default: generator = UIImpactFeedbackGenerator(style: .heavy)
          }
          generator.prepare()
          if #available(iOS 13.0, *) {
            generator.impactOccurred(intensity: CGFloat(intensity))
          } else {
            generator.impactOccurred()
          }
          result(nil)
        } else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing style/intensity", details: nil))
        }
      })
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
