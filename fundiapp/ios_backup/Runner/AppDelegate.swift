import UIKit
import Flutter
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import firebase_messaging   // Flutter plugin module: exposes FLTFirebaseMessagingPlugin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()

        // REQUIRED for firebase_messaging 16.x with UIScene lifecycle.
        // Must be called BEFORE the app finishes launching.
        FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()

        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        setupBadgeChannel(with: engineBridge.pluginRegistry)
    }

    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register: \(error.localizedDescription)")
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    private func setupBadgeChannel(with registry: FlutterPluginRegistry) {
        guard let registrar = registry.registrar(forPlugin: "BadgeChannel") else {
            print("⚠️ Badge registrar not found")
            return
        }

        let channel = FlutterMethodChannel(
            name: "com.fundapp/badge",
            binaryMessenger: registrar.messenger()
        )

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "setBadgeCount":
                guard let args = call.arguments as? [String: Any],
                      let count = args["count"] as? Int else {
                    result(false); return
                }
                if #available(iOS 16.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(count) { error in
                        if let error = error { print("❌ badge: \(error.localizedDescription)") }
                    }
                } else {
                    DispatchQueue.main.async {
                        UIApplication.shared.applicationIconBadgeNumber = count
                    }
                }
                result(true)

            case "removeBadge", "clearBadge":
                if #available(iOS 16.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(0)
                } else {
                    DispatchQueue.main.async {
                        UIApplication.shared.applicationIconBadgeNumber = 0
                    }
                }
                result(true)

            case "getBadgeCount":
                result(UIApplication.shared.applicationIconBadgeNumber)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}