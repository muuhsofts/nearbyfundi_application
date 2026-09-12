import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      setupBadgeChannel(controller: controller)
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupBadgeChannel(controller: FlutterViewController) {
    let badgeChannel = FlutterMethodChannel(
      name: "com.fundapp/badge",
      binaryMessenger: controller.binaryMessenger
    )

    badgeChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "setBadgeCount":
        if let args = call.arguments as? [String: Any],
           let count = args["count"] as? Int {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(true)
        } else {
          result(false)
        }
      case "removeBadge", "clearBadge":
        UIApplication.shared.applicationIconBadgeNumber = 0
        result(true)
      case "getBadgeCount":
        result(UIApplication.shared.applicationIconBadgeNumber)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}