# Flixie App Shortcuts and iPhone Action Button

Runner exposes three App Intents on iOS 16 and later:

- **Search Flixie** opens Discover, focuses search, displays the keyboard and
  selects any existing query. It reuses the Home Screen widget destination.
- **Open Flixie Social** opens the main Social page.
- **Open Flixie Watchlist** opens saved movies and shows.

These foreground actions open the app's registered URL scheme through UIKit.
They do not perform searches, write activity or bypass sign-in, required terms or
onboarding. All three destinations are retained through those gates.
No backend, shared account data, App Group or database seed is required.
Definitions live in `ios/Runner/AppDelegate.swift`, already part of Runner's
Sources build phase, so Xcode can extract App Intents metadata. The provider
updates its shortcut parameters on launch. No Siri entitlement is needed for
these App Intents. Older supported clients and iOS versions are unchanged.

## Set up the Action Button

After installing a new build containing these intents and opening Flixie once:

1. Open iPhone **Settings → Action Button**.
2. Select **Shortcut**, then **Choose a Shortcut**.
3. Choose **Search Flixie**, **Open Flixie Social** or **Open Watchlist**.
4. Press and hold the Action Button to run the selected action.

If the app action is not shown directly, open Apple's Shortcuts app, create a
shortcut using the corresponding Flixie action, save it, and choose that saved
shortcut in Action Button settings. The app cannot assign the button itself.
To choose between these actions on each press, create an Apple shortcut containing
**Choose from Menu** with Search, Social and Watchlist options, and put the matching Flixie
action in each branch. Assign that saved menu shortcut to the Action Button.

For an existing build with no App Shortcuts metadata, a manually created Apple
shortcut can use **URL** and **Open URLs** with `flixie:///social` or
`flixie:///search?focus=1`. Automatic search focus requires the new widget/search
implementation; older builds may simply open Discover.

## Verification before release

Use a dedicated simulator/fictional account for navigation checks, then a real
Action Button iPhone for native assignment. Check all three actions with Flixie closed,
in the background, and already foregrounded on another page; repeat search after
dismissing the keyboard and with an existing query; check signed-out recovery.
Native App Intents need a new iOS build/install, not hot reload. Verify shortcuts
appear after installing that signed build before reporting real-device success.

Apple references:
[App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts)
and [Action Button setup](https://support.apple.com/guide/shortcuts/apdfea15680b/ios).

Local validation on 4 October 2026: seven focused Flutter tests passed and focused
Dart analysis was clean. The exact App Intent definitions compiled for the arm64
iOS simulator with an iOS 15 deployment target and iOS 16 availability guards.
Apple's compile-time metadata processor successfully exported both discoverable
intents and both App Shortcuts with their titles, phrases and foreground flags.
This validates the definitions, not a full signed Runner install. No running
Flutter app was attached to the IDE daemon for restart. Full app installation and
physical Action Button execution are still unverified.

## TestFlight build 91

Uploaded 1.0.1 (91) on 4 October 2026 at Apple's confirmed upload completion.
The final signed IPA includes both discoverable shortcuts and their metadata.
Use this new build to verify the steps above on a real Action Button iPhone.


## Watchlist — 5 October 2026

**Open Flixie Watchlist** is a third App Intent/Shortcut, opening
`flixie:///watchlist`. Choose **Open Watchlist** in Settings → Action Button →
Shortcut, or add it to your existing Choose from Menu shortcut alongside Search
and Social. The destination survives login/onboarding. Hardware assignment and
execution still require an iPhone with an Action Button and a new native install.
