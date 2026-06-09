# Mobile stack

Dosey's mobile app direction is Flutter/Dart for Android and iOS.

First physical test device: 2024 Moto G Play. Keep iOS support in the architecture and wrap BLE, notifications, database, and permissions behind app-owned interfaces.

## Current app

The Flutter app lives in `mobile_app/dosey_app/`. It currently has a safety-first home screen, placeholder controller/manual dispense sections, and app-owned interfaces for controller communication, reminders, permissions, and dose logging.

Do not add a real BLE package until the command/status protocol in `docs/protocol.md` is drafted.

## Local toolchain

- Flutter 3.44.1 stable
- Dart 3.12.1
- Android command-line tools at `/opt/homebrew/share/android-commandlinetools`
- Android SDK Platform 36, Platform-Tools 37.0.0, Build-Tools 36.0.0, NDK 28.2.13676358, and CMake 3.22.1
- Homebrew OpenJDK 17 configured through `flutter config --jdk-dir`
- CocoaPods 1.16.2 for future iOS plugin work

Full Xcode is still required before iOS builds can run.

## Commands

Run from `mobile_app/dosey_app/`:

```sh
dart format .
flutter analyze
flutter test
flutter build apk --debug
```
