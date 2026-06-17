# Mobile stack

Dosey's mobile app direction is Flutter/Dart for Android and iOS.

First physical test device: 2024 Moto G Play. Keep iOS support in the architecture and wrap BLE, notifications, auth, database, and permissions behind app-owned interfaces.

## Current app

The Flutter app lives in `mobile_app/dosey_app/`. It currently has a plain five-tab shell: Today, Reminders, Controller, Log, and Settings. It also has safety acknowledgement storage, simple local reminder add/edit/delete controls, Google/Apple sign-in behind app-owned auth interfaces, a controller simulator, app-owned interfaces for controller communication, reminders, permissions, and dose logging, and a local Drift/SQLite data layer.

The selected background foundation packages are:

- `flutter_blue_plus` for BLE foundation only. The controller protocol is still not complete.
- `connectivity_plus` for advisory connectivity and Wi-Fi status only. It does not handle Wi-Fi provisioning.
- `google_sign_in` plus a native iOS Apple sign-in bridge for Google/Apple-only auth.
- `flutter_local_notifications` for local notifications and reminder sounds.
- `permission_handler` for runtime permission requests/checks.

Do not treat the BLE layer as product-ready controller behavior until the command/status protocol in `docs/protocol.md` is finished. Do not add Firebase, Supabase, cloud sync, or push notifications until the backend direction is chosen.

## Device roles

- `androidRobot`: Android phone lives in the robot and can host robot-control behavior.
- `androidPersonal`: personal Android phone for reminders, notifications, and app use.
- `iosPersonal`: personal iPhone for reminders, notifications, and app use.

iOS cannot be selected as the embedded robot phone. Robot-control features should stay gated behind Android robot mode and controller connection state.

## Local data

The phone app uses Drift on SQLite for local data. Current local tables cover app settings, reminder schedules, cached auth state, and dose log events. The dose log keeps controller dispense success separate from dose taken confirmation, so servo movement never marks a dose as taken.

The ESP32 controller should not run SQLite. It may keep tiny controller state in flash later. Cloud sync can be added after the local schema and safety flow are stable.

Notification channel IDs and sound IDs should remain stable once shipped so scheduled reminder behavior stays predictable. Custom sound assets may still need Android/iOS asset provisioning.

Current backend status: no Firebase, no Supabase, no cloud sync, and no push notifications yet.

## Local toolchain

- Flutter 3.44.1 stable
- Dart 3.12.1
- Android command-line tools at `/opt/homebrew/share/android-commandlinetools`
- Android SDK Platforms 35 and 36, Platform-Tools 37.0.0, Build-Tools 36.0.0, NDK 28.2.13676358, and CMake 3.22.1
- Homebrew OpenJDK 17 configured through `flutter config --jdk-dir`
- CocoaPods 1.16.2 for future iOS plugin work
- Xcode 26.5 selected at `/Applications/Xcode.app/Contents/Developer`

Local Android debug APK builds and iOS no-codesign debug builds run from this machine.

## Commands

Run from `mobile_app/dosey_app/`:

```sh
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
# After Drift schema changes:
dart run build_runner build
```
