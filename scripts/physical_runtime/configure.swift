import Foundation

// Operates only on an explicitly supplied temporary copy, never the source checkout.
let root = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
precondition(root.path.hasPrefix("/private/tmp/flixie-physical-") || root.path.hasPrefix("/tmp/flixie-physical-"))
let project = root.appendingPathComponent("ios/Runner.xcodeproj/project.pbxproj")
var plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: project), format: nil) as! [String: Any]
var objects = plist["objects"] as! [String: [String: Any]]
let appID = "com.flixie.flixieBenchmark"
let team = CommandLine.arguments[2]
for (id, var object) in objects {
  if object["isa"] as? String == "XCBuildConfiguration", var settings = object["buildSettings"] as? [String: Any], let bundle = settings["PRODUCT_BUNDLE_IDENTIFIER"] as? String {
    settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle.replacingOccurrences(of: "com.flixie.flixieApp", with: appID)
    settings["CODE_SIGN_ENTITLEMENTS"] = "Runner/Benchmark.entitlements"
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["DEVELOPMENT_TEAM"] = team
    object["buildSettings"] = settings
    objects[id] = object
  }
}
plist["objects"] = objects
try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: project)
let empty: [String: Any] = [:]
try PropertyListSerialization.data(fromPropertyList: empty, format: .xml, options: 0).write(to: root.appendingPathComponent("ios/Runner/Benchmark.entitlements"))
let infoURL = root.appendingPathComponent("ios/Runner/Info.plist")
var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as! [String: Any]
info["CFBundleDisplayName"] = "Flixie Benchmark"
info["CFBundleURLTypes"] = nil
info["FirebaseMessagingAutoInitEnabled"] = false
info["FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED"] = true
info["NSAppTransportSecurity"] = ["NSAllowsArbitraryLoads": true]
info["NSLocalNetworkUsageDescription"] = "Connect to the isolated benchmark fixture on your paired Mac."
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
let firebase: [String: Any] = ["API_KEY":"AIzaSy000000000000000000000000000000000", "GOOGLE_APP_ID":"1:123456789:ios:0123456789abcdef", "GCM_SENDER_ID":"123456789", "PROJECT_ID":"demo-flixie-review", "BUNDLE_ID":appID,"STORAGE_BUCKET":"demo-flixie-review.appspot.com","PLIST_VERSION":"1","IS_ANALYTICS_ENABLED":false,"IS_ADS_ENABLED":false,"IS_APPINVITE_ENABLED":false,"IS_GCM_ENABLED":false,"IS_SIGNIN_ENABLED":true]
try PropertyListSerialization.data(fromPropertyList: firebase, format: .xml, options: 0).write(to: root.appendingPathComponent("ios/Runner/GoogleService-Info.plist"))
print("Configured isolated benchmark bundle in \(root.path)")
let delegateURL = root.appendingPathComponent("ios/Runner/AppDelegate.swift")
let delegate = try String(contentsOf: delegateURL, encoding: .utf8)
    .replacingOccurrences(of: "application.registerForRemoteNotifications()", with: "// Benchmark: no APNs registration.")
    .replacingOccurrences(of: "group.com.flixie.flixieApp", with: "group.com.flixie.flixieBenchmark")
try delegate.write(to: delegateURL, atomically: true, encoding: .utf8)
let pubspecURL = root.appendingPathComponent("pubspec.yaml")
try String(contentsOf: pubspecURL, encoding: .utf8)
    .replacingOccurrences(of: "com.flixie.flixieApp", with: appID)
    .write(to: pubspecURL, atomically: true, encoding: .utf8)
// Production release configuration intentionally pins main.dart and production
// API defines. This copied benchmark must inherit its explicitly supplied target.
let releaseURL = root.appendingPathComponent("ios/Flutter/Release.xcconfig")
try "#include? \"Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig\"\n#include \"Generated.xcconfig\"\n".write(to: releaseURL, atomically: true, encoding: .utf8)
// Replace only the copy's distribution guard with a benchmark-specific guard.
// The real repository's release guard remains unchanged.
let guardURL = root.appendingPathComponent("scripts/validate-ios-release.sh")
let benchmarkGuard = """
#!/bin/sh
set -eu
[ "${PRODUCT_BUNDLE_IDENTIFIER:-}" = "com.flixie.flixieBenchmark" ] || { echo 'error: benchmark bundle required'; exit 1; }
[ "${ACTION:-}" != install ] || { echo 'error: benchmark archive/distribution forbidden'; exit 1; }
case "${FLUTTER_TARGET:-}" in
  */tool/runtime_startup.dart|tool/runtime_startup.dart|*/patrol_test/test_bundle.dart|patrol_test/test_bundle.dart) ;;
  *) echo 'error: benchmark entrypoint required'; exit 1 ;;
esac
[ "$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' "$SRCROOT/Runner/GoogleService-Info.plist")" = demo-flixie-review ] || exit 1
"""
try benchmarkGuard.write(to: guardURL, atomically: true, encoding: .utf8)
