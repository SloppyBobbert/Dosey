# Dosey app

Flutter app for the Dosey medication-dispensing companion robot prototype.

## Status badges

![Flutter](https://img.shields.io/badge/Flutter-3.44.1-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12.1-0175C2?logo=dart&logoColor=white)
![Local data](https://img.shields.io/badge/local%20data-Drift%20%2F%20SQLite-336791)
![Backend](https://img.shields.io/badge/backend-none%20yet-lightgrey)

## Current scope

- Android and iOS app shell with Today, Reminders, Controller, Log, and Settings tabs.
- Safety-first home/settings copy and safety acknowledgement storage.
- Local reminder schedule storage with simple add/edit/delete controls and enabled/disabled state.
- Controller simulator for app flow testing before BLE.
- Google sign-in through an app-owned auth interface; no Firebase/Supabase backend yet.
- App-owned interfaces for controller/Bluetooth, auth, reminders, permissions, and dose logging.
- Drift/SQLite local database for device role settings, reminders, cached auth state, and dose log events.

## Target product model

Dosey has two app modes:

- **Robot Mode:** Android-only mode for the mounted phone inside Dosey. It shows the face, reminders, dispense UI, refill status, hardware test controls, and controller connection state.
- **Personal Mode:** Android and iOS mode for patient or caregiver phones. It supports notifications, missed dose/refill visibility, dose history, and schedule editing when permissions allow.

The phone is the brain. It handles schedules, medication data, refill logic, dose history, PIN, caregiver logic, UI, reminders, Bluetooth commands, and future cloud or voice features. The XIAO should only execute hardware actions and report status.

Device role rules:

- Android can be the robot phone that lives in Dosey.
- Android can also be a personal phone for notifications and app use.
- iOS can only be a personal phone; it cannot be the robot's embedded phone.

## What works locally

- Create, edit, disable, and delete local reminders.
- Store device role, safety acknowledgement, cached auth state, and dose log events locally.
- Exercise controller flows with a simulator before BLE exists.
- Run Android debug APK and iOS no-codesign debug builds on this machine.

The app must not mark a dose taken because the servo moved. Dispense logging requires a controller success event, and later versions should separately track dose visible and dose taken confirmation.

## Near-term app work

- Draft the Bluetooth command/status/heartbeat protocol before adding a BLE package.
- Implement Robot Mode flows for guided Daviky carousel loading, dispense confirmation, refill countdown, and hardware tests.
- Include dose actions for take now, take early, take late, snooze, skip, mark already taken, ask caregiver, and mark missed.
- Add heartbeat/offline detection for XIAO power loss, crash, disconnect, or missed responses.
- Keep caregiver alerts, Piper voices, voice commands, cloud sync, facial recognition, and local AI as later features.

## Local commands

Run from this directory:

```sh
flutter pub get
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
git diff --check
```

## CI commands

Mobile CI runs the non-iOS subset on GitHub Actions:

```sh
flutter pub get
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

The workflow also checks committed whitespace with `git diff --check` and uploads the Android debug APK as a short-lived artifact. iOS no-codesign builds still run locally.

## Local toolchain notes

- Android SDK: `/opt/homebrew/share/android-commandlinetools`.
- JDK: Homebrew OpenJDK 17.
- Android packages installed: platform-tools, Android SDK Platforms 35 and 36, Build-Tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1.
- Xcode 26.5 is selected at `/Applications/Xcode.app/Contents/Developer`; no-codesign iOS debug builds run locally.
