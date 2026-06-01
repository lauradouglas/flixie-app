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
├── main.dart
├── firebase_options.dart
├── presentation/                # Presentation shared modules/controllers
├── domain/                      # Use cases and repository contracts
├── data/                        # Repository implementations
├── providers/                   # App/session state providers
├── screens/                     # Feature screens and screen-local widgets
├── services/                    # External/API/Firebase service clients
├── widgets/                     # Shared UI scaffolding primitives
└── theme/                       # Design tokens and ThemeData
test/
├── widget_test.dart                 # Unit & widget tests
└── stats_widgets_test.dart          # Stats reusable widget tests
android/                         # Android-specific configuration
ios/                             # iOS-specific configuration
```

## Architecture Rules

- UI flows should go through `presentation` controllers/use-cases/repositories, not direct `UserService` or `FriendService` calls.
- Dependency direction: `presentation -> domain`, `data -> domain`, `data -> services`.
- Shared authenticated screen chrome uses `FlixiePageScaffold`, `FlixieTitleAppBar`, and `FlixieSectionHeader`.
- See `/tmp/workspace/lauradouglas/flixie-app/docs/architecture.md` for conventions, migration status, and PR checklist guardrails.

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

The app uses the current Flixie dark palette:

| Token | Colour | Hex |
|---|---|---|
| Primary | Purple | `#9B6BFF` |
| Secondary | Cyan | `#00D1C7` |
| Tertiary | Peach | `#F1A77A` |
| Success | Green | `#00D97E` |
| Warning | Gold | `#FFC857` |
| Danger | Red | `#E57373` |
| Background | Deep Plum | `#120A24` |
| Surface | Plum | `#1A1033` |
| Surface Elevated | Plum Elevated | `#27194A` |
