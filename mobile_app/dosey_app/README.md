# Dosey app

Flutter app for the Dosey medication-reminder robot prototype.

## Current scope

- Android and iOS app shell.
- Safety-first home screen.
- Placeholder controller status and manual dispense test areas.
- App-owned interfaces for controller/BLE, reminders, permissions, and dose logging.
- Drift/SQLite local database for device role settings and dose log events.

Device role rules:

- Android can be the robot phone that lives in Dosey.
- Android can also be a personal phone for notifications and app use.
- iOS can only be a personal phone; it cannot be the robot's embedded phone.

The app must not mark a dose taken because the servo moved. Dispense logging requires a controller success event, and later versions should require drop/cup confirmation.

## Local commands

Run from this directory:

```sh
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
# After Drift schema changes:
dart run build_runner build
```

## Local toolchain notes

- Android SDK: `/opt/homebrew/share/android-commandlinetools`
- JDK: Homebrew OpenJDK 17
- Android packages installed: platform-tools, Android SDK Platforms 35 and 36, Build-Tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1
- CocoaPods 1.16.2 is installed for future iOS plugin work.
- Xcode 26.5 is selected at `/Applications/Xcode.app/Contents/Developer`; no-codesign iOS debug builds run locally.
