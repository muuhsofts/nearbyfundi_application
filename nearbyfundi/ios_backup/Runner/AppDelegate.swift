import Flutter
import UIKit
import UserNotifications
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {

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
    //    Needed to receive foreground notifications
    //    and handle tap actions.
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
    // 4. Register Flutter plugins
    // ─────────────────────────────────────────────
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ─────────────────────────────────────────────
  // APNs token → Firebase
  // FCM needs the APNs token to deliver iOS pushes.
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
  // Without this, iOS silently swallows notifications
  // when the app is in the foreground.
  // ─────────────────────────────────────────────
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show banner + update badge + play sound even when app is foregrounded
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .badge, .sound])
    } else {
      completionHandler([.alert, .badge, .sound])
    }
  }
}