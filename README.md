# Flixie App

A Flutter frontend for the Flixie backend, targeting **Android** and **iOS**.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.0.0
- Android Studio or Xcode (for device/emulator builds)

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

### Testing

```bash
flutter test
```

## Project Structure

```
lib/
├── main.dart              # App entry point & bottom navigation shell
├── theme/
│   └── app_theme.dart     # Flixie colour palette & ThemeData
└── screens/
    ├── home_screen.dart   # Home / featured content
    ├── search_screen.dart # Search & genre browsing
    └── profile_screen.dart# User profile & settings
test/
└── widget_test.dart       # Unit & widget tests
android/                   # Android-specific configuration
ios/                       # iOS-specific configuration
```

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
