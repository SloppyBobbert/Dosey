# Mobile app

Flutter app workspace for Dosey.

The app lives in `mobile_app/dosey_app/` and keeps Android and iOS personal-phone support in scope. Robot Mode is Android-only because the embedded robot phone is mounted inside Dosey.

## Quick status

| Item | Status |
| --- | --- |
| App shell | Today, Reminders, Controller, Log, Settings |
| Local storage | Drift/SQLite on the phone app only |
| Reminders | Local add/edit/delete and enabled state |
| Auth | Google sign-in wrapper, no backend yet |
| Controller | Simulator only; no BLE package yet |
| Builds | Android debug APK and iOS no-codesign debug build run locally |

## Current app

- Flutter/Dart app shell with Today, Reminders, Controller, Log, and Settings tabs.
- Safety-first home/settings copy and safety acknowledgement storage.
- Local Drift/SQLite database for app settings, reminder schedules, cached auth state, and dose logs.
- Simple local reminder add/edit/delete controls with enabled/disabled state.
- Device roles: Android robot phone, Android personal phone, and iOS personal phone only.
- Google sign-in is behind an app-owned interface with no Firebase/Supabase backend yet.
- Controller simulator, notifications, storage, auth, and permission seams stay behind app-owned interfaces.
- First physical test device: 2024 Moto G Play.

## Target app direction

Robot Mode on the mounted Android phone should handle the face screen, reminders, dispense UI, hardware test screen, Bluetooth connection, refill status, dose history, sounds or text-to-speech, and full-screen behavior when practical.

Personal Mode should handle patient or caregiver notifications, missed dose/refill alerts, dose history, and medication schedule editing when permissions allow.

The phone owns medication schedules, medication data, refill logic, PIN rules, caregiver logic, and dose states. The XIAO should only execute and report hardware actions.

Run Flutter commands from `mobile_app/dosey_app/`.

## Local commands

```sh
cd mobile_app/dosey_app
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
git diff --check
```

Android SDK platforms 35 and 36 and OpenJDK 17 are configured locally for the first Moto G Play builds. Xcode 26.5 is configured for local iOS no-codesign builds.

## CI

GitHub Actions runs Mobile CI for pull requests and pushes to `main`. The workflow checks committed whitespace, generated Drift code, formatting, analyzer output, tests, and an Android debug APK build from `mobile_app/dosey_app/`.

The Android debug APK is uploaded as a short-lived workflow artifact for basic install/build confirmation. It is not a release build.

iOS no-codesign builds still run locally because GitHub macOS runners are slower and costlier.
