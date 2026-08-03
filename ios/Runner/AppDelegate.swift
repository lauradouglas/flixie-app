import Flutter
import UIKit
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {
  private let badgeChannelName = "flixie/app_badge"
  private var badgeChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Request authorisation for remote notifications; the actual permission
    // prompt is shown by firebase_messaging / flutter_local_notifications.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // Explicitly register for APNs so iOS can issue a device token.
    application.registerForRemoteNotifications()

    // Surface native FCM token updates for diagnostics.
    Messaging.messaging().delegate = self

    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if badgeChannel == nil,
       let controller = window?.rootViewController as? FlutterViewController {
      registerBadgeChannel(with: controller.binaryMessenger)
    }

    return didFinish
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBadgeChannel(with: engineBridge.applicationRegistrar.messenger())
  }

  private func registerBadgeChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: badgeChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleBadgeMethodCall(call, result: result)
    }
    badgeChannel = channel
  }

  // Forward APNs device tokens to Firebase Messaging so FCM can work on iOS.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    print("[FCM][iOS] APNs device token received (\(deviceToken.count) bytes)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[FCM][iOS] Failed to register for remote notifications: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("[FCM][iOS] Native Messaging delegate token update: \(fcmToken ?? "<null>")")
  }

  private func handleBadgeMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setCount":
      let args = call.arguments as? [String: Any]
      let count = args?["count"] as? Int ?? 0
      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = max(0, count)
        result(nil)
      }
    case "clear":
      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = 0
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

}
