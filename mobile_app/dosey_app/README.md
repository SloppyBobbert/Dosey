# Dosey app

Flutter app for the Dosey medication-reminder robot prototype.

## Current scope

- Android and iOS app shell.
- Safety-first home screen.
- Placeholder controller status and manual dispense test areas.
- App-owned interfaces for controller/BLE, reminders, permissions, and dose logging.

The app must not mark a dose taken because the servo moved. Dispense logging requires a controller success event, and later versions should require drop/cup confirmation.

## Local commands

Run from this directory:

```sh
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

## Local toolchain notes

- Android SDK: `/opt/homebrew/share/android-commandlinetools`
- JDK: Homebrew OpenJDK 17
- Android packages installed: platform-tools, Android SDK Platform 36, Build-Tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1
- CocoaPods 1.16.2 is installed for future iOS plugin work.
- Full Xcode still needs to be installed before iOS builds can run.
