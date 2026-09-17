import Flutter
import UIKit
import UserNotifications
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ─────────────────────────────────────────────
    // 1. Initialize Firebase
    //    Required so FCM can register the APNs token.
    // ─────────────────────────────────────────────
    FirebaseApp.configure()

    // ─────────────────────────────────────────────
    // 2. Set notification center delegate
    // ─────────────────────────────────────────────
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // ─────────────────────────────────────────────
    // 3. Request notification permissions
    //    (.badge is what enables the app icon badge)
    // ─────────────────────────────────────────────
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { granted, error in
        if let error = error {
          print("❌ Notification permission error: \(error.localizedDescription)")
          return
        }
        print("✅ Notification permission granted: \(granted)")
        if granted {
          DispatchQueue.main.async {
            application.registerForRemoteNotifications()
          }
        }
      }
    )

    // ─────────────────────────────────────────────
    // 4. Call super
    // ─────────────────────────────────────────────
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // ─────────────────────────────────────────────
    // 5. Set up the native badge channel
    //    (matches your existing com.fundapp/badge channel)
    // ─────────────────────────────────────────────
    if let controller = window?.rootViewController as? FlutterViewController {
      setupBadgeChannel(controller: controller)
    }

    return result
  }

  // ─────────────────────────────────────────────
  // Flutter engine — registers plugins automatically
  // ─────────────────────────────────────────────
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // ─────────────────────────────────────────────
  // APNs token → Firebase
  // ─────────────────────────────────────────────
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    print("🍎 APNs token registered with Firebase")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // ─────────────────────────────────────────────
  // APNs registration failure — log for debugging
  // ─────────────────────────────────────────────
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // ─────────────────────────────────────────────
  // Foreground notification display
  // ─────────────────────────────────────────────
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }

  // ─────────────────────────────────────────────
  // Native badge channel
  // Called from Flutter via MethodChannel('com.fundapp/badge')
  // ─────────────────────────────────────────────
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
          print("🔴 iOS badge set to \(count) via native channel")
          result(true)
        } else {
          result(false)
        }

      case "removeBadge", "clearBadge":
        UIApplication.shared.applicationIconBadgeNumber = 0
        print("🔴 iOS badge cleared via native channel")
        result(true)

      case "getBadgeCount":
        result(UIApplication.shared.applicationIconBadgeNumber)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}