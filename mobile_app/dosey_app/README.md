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
- Local-only household/profile scaffold with robot phone metadata. Cloud sync, invites, and shared household state are not active yet.
- Four-digit Action PIN gating for protected admin edits, plus a separate local admin audit history for prescription, schedule, carousel, household/profile, and PIN lifecycle changes.
- Carousel loading workflow with Daviky slot assignment, loaded/dispensed/review states, and controller-gated dispense actions.
- Today dose-state logging that keeps dispense, visible, taken, skipped, missed, and caregiver/help actions separate.
- Robot Face scaffolding with local face-state timing settings for wake-before-dose and stay-awake-after-dose behavior.
- Mounted Robot Mode behavior that returns to Robot Face on resume, Back, or configurable inactivity; routes local notification taps by role and alert type; and keeps the Android display awake only while Robot Face is active and the app is resumed, never while backgrounded.
- Fixed WAV voice catalog for the mounted Robot Mode phone, with app-owned asset playback wiring, previews, category toggles, quiet hours, configurable repetition cooldowns, and reminder repeat policy controls for normal reminder speech.
- Controller simulator plus a compile-tested D1 BLE transport and staged controller gateway; physical BLE behavior is still unverified.
- Google and Apple sign-in through app-owned auth interfaces; no Firebase/Supabase backend yet.
- App-owned interfaces for controller/BLE, connectivity, auth, reminders, permissions, notifications, and dose logging.
- Drift/SQLite local database for device role settings, prescriptions, reminders, schedule profiles, carousel slots, cached auth state, refill records, dose log events, household/profile metadata, and admin audit events.

Selected background packages:

- `flutter_blue_plus` for filtered Dosey discovery, GATT service discovery, notifications, and bounded D1 writes.
- `connectivity_plus` for advisory connectivity/Wi-Fi status only, not provisioning.
- `google_sign_in` plus a native iOS Apple sign-in bridge for Google/Apple-only auth.
- `flutter_local_notifications` for local reminder notifications and sounds.
- `permission_handler` for runtime permission requests/checks. Android 12 and
  newer request nearby Bluetooth scan/connect access; Android 11 and older map
  the same scan gate to fine location, which Android requires for BLE scans.

Notification channel IDs and sound IDs are intended to stay stable. Custom reminder sound assets may still need platform provisioning on Android/iOS.

No cloud sync, push notifications, Firebase, or Supabase are in the app yet.

## Target product model

Dosey has two app modes:

- **Robot Mode:** Android-only mode for the mounted phone inside Dosey. It shows the face, reminders, dispense UI, refill status, hardware test controls, and controller connection state. It uses soft in-app navigation and screen-awake guardrails rather than device-owner or lock-task kiosk provisioning.
- **Personal Mode:** Android and iOS mode for patient or caregiver phones. It supports notifications, missed dose/refill visibility, dose history, and schedule editing when permissions allow.

The phone is the brain. It handles schedules, medication data, refill logic, dose history, PIN, caregiver logic, UI, reminders, Bluetooth commands, and future cloud, voice-command, or local AI features. The XIAO should only execute hardware actions and report status.

Device role rules:

- Android can be the robot phone that lives in Dosey.
- Android can also be a personal phone for notifications and app use.
- iOS can only be a personal phone; it cannot be the robot's embedded phone.

## What works locally

- Create, edit, and delete local prescriptions and reminders.
- Track remaining doses, refill thresholds, refill warnings, and refill-add history locally.
- Assign reminders to Daviky carousel slots and exercise controller flows with either the simulator or the compile-tested BLE bench path.
- Log Today actions separately for dispense success, dose visible, taken confirmations, already taken, early/late taken, snooze, skip, missed, and caregiver help.
- Prevent duplicate terminal Today actions from double-logging the same dose or spending inventory twice.
- Store device role, safety acknowledgement, cached auth state, Action PIN state, refill data, carousel state, household/profile metadata, admin audit events, and dose log events locally.
- Return mounted Robot Mode to Robot Face after 1, 2, 5, 10, or 15 minutes of inactivity, with 2 minutes as the default; pause the timer in the background and defer it while a dialog or sheet is open.
- Route local dose reminders to Robot Face in Robot Mode and Today in Personal Mode, route shortage alerts to Carousel, and run missed-dose reconciliation when the app resumes.
- Run Android debug APK and iOS no-codesign debug builds on this machine.

The app must not mark a dose taken because the servo moved. Dispense logging requires a controller success event, and the app separately tracks dose visible and dose taken confirmation.

## Near-term app work

- Physically verify BLE advertising, discovery, status, heartbeat, disconnect, and reconnect with the bare XIAO before attaching external hardware.
- Run mounted-phone manual QA on the Android test device for resume, inactivity, Back, notification, screen-awake, and role-change behavior.
- Keep Today dose actions and refill inventory behavior aligned with local-first safety rules.
- Add heartbeat/offline detection for XIAO power loss, crash, disconnect, or missed responses.
- Keep caregiver alerts, voice commands, cloud sync, facial recognition, and local AI as later features. The current voice scope is fixed prerecorded WAV phrases only.

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
