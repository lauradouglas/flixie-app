# Flixie

A Flutter frontend for the Flixie backend, targeting **Android** and **iOS**.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.2.0
- Android Studio or Xcode (for device/emulator builds)
- A Firebase project with **Email/Password** authentication enabled

### Firebase Setup

1. Create a project at [Firebase Console](https://console.firebase.google.com/).
2. Enable **Email/Password** sign-in under *Authentication → Sign-in method*.
3. Register your Android and/or iOS apps in *Project Settings → Your apps*.
4. Download the config files:
   - **Android**: `google-services.json` → place in `android/app/`
   - **iOS**: `GoogleService-Info.plist` → add to the `Runner` target in Xcode
5. Open `lib/firebase_options.dart` and replace every `YOUR_*` placeholder with the
   real values from your Firebase project (or run `flutterfire configure` to generate
   this file automatically).

### Setup

```bash
# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Building

```bash
# Android APK
flutter build apk --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

## GitHub Actions

The project includes automated workflows for building and validating the application on every push to the `main` branch.

### Android Build (`android_build.yml`)
- Triggered on pushes to `main` and `AndroidBuild`.
- Builds both the **APK** and **App Bundle (AAB)** in release mode.
- Artifacts are uploaded and available for download from the action run summary.

### iOS Build (`build.yml`)
- Triggered on pushes and pull requests to `main`.
- Validates the iOS build (using `--no-codesign`) on a `macos-latest` runner.

### Required Repository Secrets
To enable these workflows, the following GitHub Secrets must be configured in the repository:

| Secret Name | Description |
|---|---|
| `API_BASE_URL` | The base URL for the backend API |
| `FIREBASE_*` | All Firebase configuration keys (see `.firebase.json.example`) |
| `GOOGLE_SERVICES_JSON_BASE64` | Base64 encoded content of `google-services.json` |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | Base64 encoded content of `GoogleService-Info.plist` |

### Testing

```bash
flutter test
```

## Project Structure

```
lib/
├── main.dart                    # App entry point, Firebase init & GoRouter
├── firebase_options.dart        # Firebase config (replace placeholders)
├── providers/
│   └── auth_provider.dart       # Auth state (ChangeNotifier)
├── services/
│   └── auth_service.dart        # Firebase Auth wrapper
├── theme/
│   └── app_theme.dart           # Flixie colour palette & ThemeData
└── screens/
    ├── auth/
    │   ├── login_screen.dart        # Sign-in screen
    │   ├── signup_screen.dart       # Create-account screen
    │   └── forgot_password_screen.dart # Password-reset screen
    ├── home_screen.dart             # Home / featured content
    ├── search_screen.dart           # Search & genre browsing
    └── profile_screen.dart          # User profile & sign-out
test/
└── widget_test.dart             # Unit & widget tests
android/                         # Android-specific configuration
ios/                             # iOS-specific configuration
```

## Authentication Flow

| Route | Description |
|---|---|
| `/auth/login` | Email + password sign-in |
| `/auth/signup` | Create a new account (name, email, password) |
| `/auth/forgot-password` | Send a Firebase password-reset email |
| `/` | Home (requires auth) |
| `/search` | Search (requires auth) |
| `/profile` | Profile + sign-out (requires auth) |

Unauthenticated users are automatically redirected to `/auth/login`.

## Colour Scheme

The app uses a dark theme derived from the original Ionic colour palette:

| Token | Colour | Hex |
|---|---|---|
| Primary | Purple | `#947AF1` |
| Secondary | Teal | `#08A391` |
| Tertiary | Peach | `#F1A77A` |
| Success | Green | `#30C48D` |
| Warning | Yellow | `#FFD166` |
| Danger | Red | `#E57373` |
| Background | Deep Navy | `#172B4D` |
