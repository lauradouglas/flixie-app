import Flutter
import UIKit
import WidgetKit
import AppIntents
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {
  private let badgeChannelName = "flixie/app_badge"
  private let pushTapChannelName = "flixie/push_taps"
  private var widgetRevision = UUID()
  private var widgetChannel: FlutterMethodChannel?
  private var badgeChannel: FlutterMethodChannel?
  private var pushTapChannel: FlutterMethodChannel?
  private var pendingPushTap: [String: String]?

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
      registerChannels(with: controller.binaryMessenger)
    }

    if #available(iOS 16.0, *) {
      FlixieAppShortcuts.updateAppShortcutParameters()
    }

    return didFinish
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerChannels(with: engineBridge.applicationRegistrar.messenger())
  }

  private func registerChannels(with messenger: FlutterBinaryMessenger) {
    registerWatchlistWidgetChannel(with: messenger)
    registerBadgeChannel(with: messenger)
    registerPushTapChannel(with: messenger)
  }

  private func registerWatchlistWidgetChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "flixie/watchlist_widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "sync", let self = self else {
        result(FlutterMethodNotImplemented); return
      }
      let group = "group.com.flixie.flixieApp"
      guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
            let defaults = UserDefaults(suiteName: group) else {
        result(FlutterError(code: "app_group_unavailable", message: "Watchlist widget sharing is unavailable.", details: nil)); return
      }
      let args = call.arguments as? [String: Any] ?? [:]
      let revision = UUID()
      self.widgetRevision = revision
      let directory = container.appendingPathComponent("watchlist", isDirectory: true)
      try? FileManager.default.removeItem(at: directory)
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      var items = Array((args["items"] as? [[String: Any]] ?? []).prefix(4)).map { $0.filter { !($0.value is NSNull) } }
      // Publish the new account immediately; never keep the previous user's posters.
      defaults.set(items, forKey: "watchlistItems")
      defaults.set(args["account"] as? String != nil, forKey: "watchlistSignedIn")
      WidgetCenter.shared.reloadTimelines(ofKind: "FlixieWatchlistWidget")
      result(nil)
      Task { @MainActor in
        for index in items.indices {
          guard self.widgetRevision == revision else { return }
          guard let path = items[index]["poster"] as? String, path.hasPrefix("/"),
                let url = URL(string: "https://image.tmdb.org/t/p/w185" + path) else { continue }
          var request = URLRequest(url: url)
          request.timeoutInterval = 12
          guard let (data, response) = try? await URLSession.shared.data(for: request),
                self.widgetRevision == revision,
                (response as? HTTPURLResponse)?.statusCode == 200,
                data.count < 2_000_000, UIImage(data: data) != nil else { continue }
          let name = "poster-\(index).jpg"
          if (try? data.write(to: directory.appendingPathComponent(name), options: .atomic)) != nil {
            items[index]["file"] = name
          }
        }
        guard self.widgetRevision == revision else { return }
        defaults.set(items, forKey: "watchlistItems")
        WidgetCenter.shared.reloadTimelines(ofKind: "FlixieWatchlistWidget")
      }
    }
    widgetChannel = channel
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

  private func registerPushTapChannel(with messenger: FlutterBinaryMessenger) {
    guard pushTapChannel == nil else { return }
    let channel = FlutterMethodChannel(name: pushTapChannelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getInitialPushTap" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let payload = self?.pendingPushTap
      self?.pendingPushTap = nil
      result(payload)
    }
    pushTapChannel = channel
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let payload = response.notification.request.content.userInfo.reduce(into: [String: String]()) {
      result, entry in
      guard let key = entry.key as? String, key != "aps" else { return }
      result[key] = String(describing: entry.value)
    }
    print("[FCM][iOS] Native notification tap payload: \(payload)")
    if let channel = pushTapChannel {
      channel.invokeMethod("notificationTapped", arguments: payload)
    } else {
      pendingPushTap = payload
    }
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
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

// Keep App Intents in Runner's existing compiled source so Xcode extracts their
// metadata for Shortcuts. The Action Button assignment remains the user's choice.
@available(iOS 16.0, *)
struct SearchFlixieIntent: AppIntent {
  static var title: LocalizedStringResource = "Search Flixie"
  static var description = IntentDescription("Open Discover with search ready to type.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    try await openFlixieDestination("flixie:///search?focus=1")
    return .result()
  }
}

@available(iOS 16.0, *)
struct OpenFlixieSocialIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Flixie Social"
  static var description = IntentDescription("Open the Social page in Flixie.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    try await openFlixieDestination("flixie:///social")
    return .result()
  }
}

@available(iOS 16.0, *)
struct OpenFlixieWatchlistIntent: AppIntent {
  static var title: LocalizedStringResource = "Open Flixie Watchlist"
  static var description = IntentDescription("Open your saved movies and shows in Flixie.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    try await openFlixieDestination("flixie:///watchlist")
    return .result()
  }
}

@available(iOS 16.0, *)
struct FlixieAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SearchFlixieIntent(),
      phrases: ["Search in \(.applicationName)"],
      shortTitle: "Search Flixie",
      systemImageName: "magnifyingglass"
    )
    AppShortcut(
      intent: OpenFlixieWatchlistIntent(),
      phrases: ["Open my watchlist in \(.applicationName)"],
      shortTitle: "Open Watchlist",
      systemImageName: "bookmark"
    )
    AppShortcut(
      intent: OpenFlixieSocialIntent(),
      phrases: ["Open Social in \(.applicationName)"],
      shortTitle: "Open Flixie Social",
      systemImageName: "person.2"
    )
  }
}

// UIApplication supports our registered custom scheme. OpenURLIntent requires
// a universal link, so it cannot be used for these existing internal URLs.
@available(iOS 16.0, *)
@MainActor
private func openFlixieDestination(_ value: String) async throws {
  guard let url = URL(string: value), await UIApplication.shared.open(url) else {
    throw NSError(domain: "com.flixie.shortcuts", code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "Flixie could not open this page. Please open the app and try again."])
  }
}
