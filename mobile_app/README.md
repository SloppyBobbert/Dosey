# Mobile app

Flutter app workspace for Dosey.

The app lives in `mobile_app/dosey_app/` and keeps Android and iOS personal-phone support in scope. Robot Mode is Android-only because the embedded robot phone is mounted inside Dosey.

## Workspace summary

| Item | Status |
| --- | --- |
| App shell | Today, Prescriptions, Schedule, Carousel, Controller, Log, and Settings, plus Robot Face in Android Robot Mode |
| Local storage | Drift/SQLite on the phone app only |
| Prescriptions and schedules | Local prescriptions, refill inventory tracking, schedule profiles, schedule editing, and enabled state |
| Auth | Google + Apple wrappers, no backend yet |
| Carousel and controller | Daviky loading workflow, simulator, and compile-tested D1 BLE bench path; physical BLE and movement tests pending |
| Mounted Robot Mode | Face-first resume and Back behavior, configurable inactivity return, role-aware local notification routing, and screen-awake control only while Robot Face is active and the app is resumed |
| Builds | Android debug APK and iOS no-codesign debug build run locally |

## Current app

This directory is the Flutter workspace. The app itself lives in `mobile_app/dosey_app/`, which is the canonical place for current app scope and commands.

Current workspace-level status:

- Android and iOS personal-phone support stay in scope. Robot Mode stays Android-only.
- The app shell, local storage, refill tracking, reminder flows, Daviky carousel loading workflow, controller simulator, and fixed prerecorded Robot Mode voice prompts are in place.
- Mounted Robot Mode returns to Robot Face on resume and after configurable inactivity, contains Back navigation inside the app, and keeps the display awake only while Robot Face is active and the app is resumed; it does not keep the display awake while backgrounded.
- The D1 controller protocol now has a compile-tested Flutter BLE transport and staged gateway. Physical advertising, connection, and hardware behavior remain unverified.
- Google sign-in and native iOS Apple sign-in are wired behind app-owned interfaces. No backend, cloud sync, or push notifications yet.
- First physical test device: 2024 Moto G Play.

## Target app direction

Robot Mode on the mounted Android phone handles the face screen, reminders, dispense UI, missed-dose recognition, hardware test screen, refill status, dose history, fixed prerecorded voice prompts, quiet-hours behavior, and soft in-app mounted-phone guardrails. Android device-owner, lock-task, and immersive kiosk provisioning remain out of scope.

Voice commands and local AI remain future work.

Personal Mode should handle patient or caregiver notifications, missed dose/refill alerts, dose history, and medication schedule editing when permissions allow.

The phone owns medication schedules, medication data, refill logic, PIN rules, caregiver logic, and dose states. The XIAO should only execute and report hardware actions.

For detailed feature coverage, local behavior, and app-specific commands, see [`dosey_app/README.md`](dosey_app/README.md).

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
