import Flutter
import UIKit
import AVFoundation
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
  // AVAudioPlayer-based playback for reliable SFX on iOS
  private var tickPlayer: AVAudioPlayer?
  private var foundPlayer: AVAudioPlayer?
  private var invalidPlayer: AVAudioPlayer?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
  // Configure audio session for reliable playback (plays even if ringer is muted)
  configureAudioSession()
    
  // Prepare short SFX players
  loadPlayers()
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Audio method channel
    if let controller = window?.rootViewController as? FlutterViewController {
    let audioChannel = FlutterMethodChannel(name: "bwgrid/audio", binaryMessenger: controller.binaryMessenger)
      audioChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "playTick":
      self.play(self.tickPlayer)
          result(nil)
        case "playFound":
      self.play(self.foundPlayer)
          result(nil)
        case "playInvalid":
      self.play(self.invalidPlayer)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    // Haptics method channel
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "bwgrid/haptics", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "impact":
          guard let args = call.arguments as? [String: Any],
                let styleStr = args["style"] as? String else {
            result(FlutterError(code: "BAD_ARGS", message: "Missing style for impact", details: nil))
            return
          }
          let intensity = (args["intensity"] as? Double) ?? 1.0
          let style: UIImpactFeedbackGenerator.FeedbackStyle
          switch styleStr {
          case "light": style = .light
          case "medium": style = .medium
          case "rigid":
            if #available(iOS 13.0, *) { style = .rigid } else { style = .heavy }
          case "soft":
            if #available(iOS 13.0, *) { style = .soft } else { style = .light }
          case "heavy": fallthrough
          default: style = .heavy
          }
          let generator = UIImpactFeedbackGenerator(style: style)
          generator.prepare()
          if #available(iOS 13.0, *) {
            let clamped = max(0.0, min(1.0, intensity))
            generator.impactOccurred(intensity: CGFloat(clamped))
          } else {
            generator.impactOccurred()
          }
          result(nil)

        case "notification":
          guard let args = call.arguments as? [String: Any],
                let typeStr = args["type"] as? String else {
            result(FlutterError(code: "BAD_ARGS", message: "Missing type for notification", details: nil))
            return
          }
          let generator = UINotificationFeedbackGenerator()
          generator.prepare()
          let type: UINotificationFeedbackGenerator.FeedbackType
          switch typeStr {
          case "warning": type = .warning
          case "error": type = .error
          case "success": fallthrough
          default: type = .success
          }
          generator.notificationOccurred(type)
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func loadPlayers() {
    func player(for asset: String) -> AVAudioPlayer? {
      let key = FlutterDartProject.lookupKey(forAsset: asset)
      guard let path = Bundle.main.path(forResource: key, ofType: nil) else {
        print("[Audio] Asset not found: \(asset)")
        return nil
      }
      let url = URL(fileURLWithPath: path)
      do {
        let p = try AVAudioPlayer(contentsOf: url)
        p.prepareToPlay()
        p.volume = 1.0
        return p
      } catch {
        print("[Audio] Failed to init player for \(asset): \(error)")
        return nil
      }
    }
    
    tickPlayer = player(for: "assets/audio/select.mp3")
    foundPlayer = player(for: "assets/audio/word_found.mp3")
    invalidPlayer = player(for: "assets/audio/invalid.mp3")
  }

  private func play(_ player: AVAudioPlayer?) {
    guard let player = player else { return }
    do {
      // Ensure session is active before playback
      try AVAudioSession.sharedInstance().setActive(true, options: [])
    } catch {
      print("[Audio] Failed to activate audio session: \(error)")
    }
    if player.isPlaying {
      player.stop()
      player.currentTime = 0
    } else {
      player.currentTime = 0
    }
    player.play()
  }
  
  private func configureAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      // .playback plays even if device is in silent, and we allow mixing with other audio
      try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try audioSession.setActive(true)
      print("Audio session configured successfully (.playback + mixWithOthers)")
    } catch {
      print("Failed to configure audio session: \(error)")
    }
  }
}
