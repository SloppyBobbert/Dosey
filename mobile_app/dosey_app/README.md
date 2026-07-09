# Dosey app

Flutter app for the Dosey medication-dispensing companion robot prototype.

## Status badges

![Flutter](https://img.shields.io/badge/Flutter-3.44.1-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12.1-0175C2?logo=dart&logoColor=white)
![Local data](https://img.shields.io/badge/local%20data-Drift%20%2F%20SQLite-336791)
![Backend](https://img.shields.io/badge/backend-none%20yet-lightgrey)

## Current scope

- Android and iOS app shell with Today, Prescriptions, Schedule, Carousel, Controller, Log, and Settings tabs, plus a profile menu. Android Robot Mode also shows Robot Face.
- Safety-first copy and local safety acknowledgement storage.
- Local prescription storage with remaining-dose counts, refill thresholds, refill-add history, and medication-type display.
- Local reminder schedule storage with add/edit/delete controls, enabled/disabled state, duplicate-time checks, and schedule profiles.
- Carousel loading workflow with Daviky slot assignment, loaded/dispensed/review states, and controller-gated dispense actions.
- Today dose-state logging that keeps dispense, visible, taken, skipped, missed, and caregiver/help actions separate.
- Robot Face scaffolding with local face-state timing settings for wake-before-dose and stay-awake-after-dose behavior.
- Controller simulator plus BLE foundation for app flow work; controller protocol is still incomplete.
- Google and Apple sign-in through app-owned auth interfaces; no Firebase/Supabase backend yet.
- App-owned interfaces for controller/BLE, connectivity, auth, reminders, permissions, notifications, and dose logging.
- Drift/SQLite local database for device role settings, prescriptions, reminders, schedule profiles, carousel slots, cached auth state, refill records, and dose log events.

Selected background packages:

- `flutter_blue_plus` for BLE foundation only.
- `connectivity_plus` for advisory connectivity/Wi-Fi status only, not provisioning.
- `google_sign_in` plus a native iOS Apple sign-in bridge for Google/Apple-only auth.
- `flutter_local_notifications` for local reminder notifications and sounds.
- `permission_handler` for runtime permission requests/checks.

Notification channel IDs and sound IDs are intended to stay stable. Custom reminder sound assets may still need platform provisioning on Android/iOS.

No cloud sync, push notifications, Firebase, or Supabase are in the app yet.

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

- Create, edit, and delete local prescriptions and reminders.
- Track remaining doses, refill thresholds, refill warnings, and refill-add history locally.
- Assign reminders to Daviky carousel slots and exercise controller flows with a simulator before BLE exists.
- Log Today actions separately for dispense success, dose visible, taken confirmations, already taken, early/late taken, snooze, skip, missed, and caregiver help.
- Prevent duplicate terminal Today actions from double-logging the same dose or spending inventory twice.
- Store device role, safety acknowledgement, cached auth state, refill data, carousel state, and dose log events locally.
- Run Android debug APK and iOS no-codesign debug builds on this machine.

The app must not mark a dose taken because the servo moved. Dispense logging requires a controller success event, and the app separately tracks dose visible and dose taken confirmation.

## Near-term app work

- Draft and test the Bluetooth command/status/heartbeat protocol against the simulator before hardware integration.
- Keep expanding Robot Mode flows around guided Daviky carousel loading, dispense confirmation, refill countdown, and hardware tests.
- Keep Today dose actions and refill inventory behavior aligned with local-first safety rules.
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
