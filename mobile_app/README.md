# Mobile app

Flutter app workspace for Dosey.

The app lives in `mobile_app/dosey_app/` and keeps Android and iOS personal-phone support in scope. Robot Mode is Android-only because the embedded robot phone is mounted inside Dosey.

## Quick status

| Item | Status |
| --- | --- |
| App shell | Today, Prescriptions, Schedule, Robot Face-first Android Robot Mode, Carousel, Controller, Log, Settings, plus profile menu and active section title |
| Local storage | Drift/SQLite on the phone app only |
| Prescriptions and schedules | Local prescriptions, refill inventory tracking, schedule profiles, schedule editing, and enabled state |
| Auth | Google + Apple wrappers, no backend yet |
| Carousel and controller | Polished loading-bay and hardware-bench views, Daviky slot loading workflow, simulator, and BLE foundation only; real protocol incomplete |
| Builds | Android debug APK and iOS no-codesign debug build run locally |

## Current app

- Flutter/Dart app shell with Today, Prescriptions, Schedule, Carousel, Controller, Log, and Settings tabs, plus a Robot Face tab when the device role can host the robot, a profile menu, and active section title in the top app bar.
- Safety-first home/settings copy, profile/account settings, profile menu shortcuts, and safety acknowledgement storage.
- Polished dashboard cards for the core local workflow: medication cabinet, routine builder, Today next-dose timeline that skips locally completed, skipped, or missed doses, Android Robot Face, Carousel loading bay, Controller hardware bench, and local dose-history audit trail.
- Local Drift/SQLite database for app settings, prescriptions, schedule profiles, reminder schedules, carousel slots, cached auth state, and dose logs.
- Local prescription and schedule editing with remaining-dose counts, refill thresholds, refill-add history, schedule profiles, enabled/disabled state, and duplicate-time checks.
- Today dose actions only spend inventory for taken-style confirmations, while duplicate terminal actions for the same dose are ignored.
- Daviky carousel loading workflow that assigns schedules to slots, marks slots loaded, shows loaded/ready counts, disables dispense buttons while the controller is offline, and logs dispense movement separately from taken confirmation.
- Android Robot Mode opens Robot Face first, with tap-to-wake interaction, clearer mounted-phone sleepy/awake visuals, and local wake-before-dose, stay-awake, flip, and dimming settings.
- Robot Face has simulator-backed dose states, a dominant red missed-dose alert, and a non-terminal missed-dose recognition action. Recognition records that the warning was seen; it does not mark the dose taken, skipped, or inventory-changing.
- Device roles: Android robot phone, Android personal phone, and iOS personal phone only.
- `flutter_blue_plus` BLE foundation behind an app-owned interface; protocol still incomplete.
- `connectivity_plus` behind an app-owned interface for advisory connectivity/Wi-Fi status only, not provisioning.
- `google_sign_in` plus a native iOS Apple sign-in bridge behind app-owned auth interfaces with no Firebase/Supabase backend yet.
- `flutter_local_notifications` for local reminder notifications; channel/sound IDs are meant to stay stable, but custom sound assets may still need platform provisioning.
- `permission_handler` behind an app-owned runtime permission interface.
- No cloud sync or push notifications yet.
- First physical test device: 2024 Moto G Play.

## Target app direction

Robot Mode on the mounted Android phone should handle the face screen, reminders, dispense UI, missed-dose recognition, hardware test screen, Bluetooth connection, refill status, dose history, sounds or text-to-speech, and full-screen behavior when practical.

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
