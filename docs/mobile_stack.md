# Mobile stack

Dosey's mobile app direction is Flutter/Dart for Android and iOS.

Android is the practical platform for Robot Mode because the mounted phone lives inside the robot. iOS remains in scope for Personal Mode only.

## Current app

The Flutter app lives in `mobile_app/dosey_app/`. It currently has a plain five-tab shell: Today, Reminders, Controller, Log, and Settings. It also has safety acknowledgement storage, simple local reminder add/edit/delete controls, Google/Apple sign-in behind app-owned auth interfaces, a controller simulator, app-owned interfaces for controller communication, reminders, permissions, and dose logging, and a local Drift/SQLite data layer.

The selected background foundation packages are:

- `flutter_blue_plus` for BLE foundation only. The controller protocol is still not complete.
- `connectivity_plus` for advisory connectivity and Wi-Fi status only. It does not handle Wi-Fi provisioning.
- `google_sign_in` plus a native iOS Apple sign-in bridge for Google/Apple-only auth.
- `flutter_local_notifications` for local notifications and reminder sounds.
- `permission_handler` for runtime permission requests/checks.

Do not treat the BLE layer as product-ready controller behavior until the command/status protocol in `docs/protocol.md` is finished. Do not add Firebase, Supabase, cloud sync, or push notifications until the backend direction is chosen.

## Device modes

- **Robot Mode:** runs on the mounted Android phone inside Dosey.
- **Personal Mode:** runs on patient or caregiver Android and iOS phones.

Device role rules:

- `androidRobot`: Android phone lives in Dosey and can host robot-control behavior.
- `androidPersonal`: personal Android phone for reminders, notifications, schedule edits, and app use.
- `iosPersonal`: personal iPhone for reminders, notifications, schedule edits, and app use.

iOS cannot be selected as the embedded robot phone. Robot-control features should stay gated behind Android robot mode and controller connection state.

If the user does not sign in and the device is Android, the prototype may support Robot Mode locally. Account, family, and cloud features can come later.

## Phone responsibilities

The phone is the brain of Dosey. It handles:

- Medication schedule.
- Manual medication database.
- Refill tracking.
- Dose history.
- Cute animated face.
- Voice reminders, sound effects, or text-to-speech.
- User interface.
- Optional PIN authorization.
- Caregiver alerts and family permissions later.
- Early, late, missed, skipped, snoozed, and already-taken dose logic.
- Bluetooth commands to the XIAO.
- Wi-Fi updates and future cloud sync.
- Optional future voice commands and local AI features.

## XIAO boundary

The XIAO should not handle medication names, schedules, dose decisions, caregiver logic, PIN logic, voice generation, AI conversation, or medical advice. It should only report hardware status and execute hardware commands.

## MVP app features

- Medication schedule setup.
- Manual medication database.
- Guided Daviky carousel loading.
- Dose reminders.
- Dispense button.
- Bluetooth connection to XIAO with acknowledgements.
- Hardware test screen.
- Dose history.
- Refill countdown and refill alerts.
- Early dose, late dose, missed dose, snooze, skip, and already-taken flows.
- Optional PIN authorization.
- Basic cute animated face.
- Basic sound or voice reminder placeholder.
- Basic caregiver contact setup.
- Heartbeat/offline detection for XIAO power loss, crash, disconnect, or missed responses.

## Local data

The phone app uses Drift on SQLite for local data. Current local tables cover app settings, reminder schedules, cached auth state, and dose log events. The dose log keeps controller dispense success separate from dose taken confirmation, so servo movement never marks a dose as taken.

The ESP32 controller should not run SQLite. It may keep tiny controller state in flash later. Cloud sync can be added after the local schema and safety flow are stable.

Notification channel IDs and sound IDs should remain stable once shipped so scheduled reminder behavior stays predictable. Custom sound assets may still need Android/iOS asset provisioning.

Current backend status: no Firebase, no Supabase, no cloud sync, and no push notifications yet.

## Local toolchain

- Flutter 3.44.1 stable.
- Dart 3.12.1.
- Android command-line tools at `/opt/homebrew/share/android-commandlinetools`.
- Android SDK Platforms 35 and 36, Platform-Tools 37.0.0, Build-Tools 36.0.0, NDK 28.2.13676358, and CMake 3.22.1.
- Homebrew OpenJDK 17 configured through `flutter config --jdk-dir`.
- Xcode 26.5 selected at `/Applications/Xcode.app/Contents/Developer`.

Local Android debug APK builds and iOS no-codesign debug builds run from this machine.

## Commands

Run from `mobile_app/dosey_app/`:

```sh
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
git diff --check
```
