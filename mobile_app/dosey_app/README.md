# Dosey app

Flutter app for the Dosey medication-dispensing companion robot prototype.

## Status badges

![Flutter](https://img.shields.io/badge/Flutter-3.44.6-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12.2-0175C2?logo=dart&logoColor=white)
![Local data](https://img.shields.io/badge/local%20data-Drift%20%2F%20SQLite-336791)
![Backend](https://img.shields.io/badge/backend-Appwrite-F02E65?logo=appwrite&logoColor=white)

## Current scope

- Three visible destinations: Today, Medications, and Settings. Schedule, Prescriptions, and carousel management are under Medications; technical tools are protected in Robot Maintenance; the Robot distribution retains full-screen Robot Face.
- Safety-first copy and local safety acknowledgement storage.
- Local prescription storage with remaining-dose counts, refill thresholds, refill-add history, and medication-type display.
- Local reminder schedule storage with add/edit/delete controls, enabled/disabled state, duplicate-time checks, and schedule profiles.
- Local household/profile metadata plus Appwrite-backed robot ownership and current legacy mounted-phone pairing. Personal account and household use requires human authentication; the Robot distribution remains usable as a guest. Secure mounted-access restoration is a pending mobile follow-up; the live staging backend rollout remains pending/incomplete.
- Four-digit Action PIN gating for protected admin edits, plus a separate local admin audit history for prescription, schedule, carousel, household/profile, and PIN lifecycle changes.
- Carousel loading workflow with Daviky slot assignment, loaded/dispensed/review states, and controller-gated dispense actions.
- Today dose-state logging that keeps dispense, visible, taken, skipped, missed, and caregiver/help actions separate.
- Robot Face scaffolding with local face-state timing settings for wake-before-dose and stay-awake-after-dose behavior.
- Mounted Robot Mode behavior that returns to Robot Face on resume, Back, or configurable inactivity; routes local notification taps by role and alert type; and keeps the Android display awake only while Robot Face is active and the app is resumed, never while backgrounded.
- Fixed WAV voice catalog for the mounted Robot Mode phone, with app-owned asset playback wiring, previews, category toggles, quiet hours, configurable repetition cooldowns, and reminder repeat policy controls for normal reminder speech.
- Controller simulator plus a compile-tested D1 BLE transport and staged controller gateway; physical BLE behavior is still unverified.
- Guided Trial scenarios for simulator-backed happy-path dispensing, missed-dose recognition, and offline/reconnect behavior.
- Appwrite-backed human identity and robot linking plus native iOS Apple sign-in, all behind app-owned interfaces. Human authentication, device pairing, and hardware authorization are independent capabilities: sign-in/sign-out does not change pairing, hardware authorization, settings, or local medication data, and pairing does not alter human authentication.
- App-owned interfaces for controller/BLE, connectivity, auth, robot pairing, reminders, permissions, notifications, and dose logging.
- Drift/SQLite local database for device role settings, prescriptions, reminders, schedule profiles, carousel slots, cached auth state, refill records, dose log events, household/profile metadata, and admin audit events.

Selected background packages:

- `flutter_blue_plus` for filtered Dosey discovery, GATT service discovery, notifications, and bounded D1 writes.
- `connectivity_plus` for advisory connectivity/Wi-Fi status only, not provisioning.
- `appwrite` for human identity, robot ownership, and current legacy mounted-phone pairing. The target secure path uses server-only `mounted_robot_access` and `get-mounted-robot`; anonymous Robot accounts must never join or enumerate Teams on that path, which remain for human household ownership and membership.
- `google_sign_in` plus a native iOS Apple sign-in bridge for local/provider-specific auth paths.
- `flutter_local_notifications` for local reminder notifications and sounds.
- `permission_handler` for runtime permission requests/checks. Android 12 and
  newer request nearby Bluetooth scan/connect access; Android 11 and older map
  the same scan gate to fine location, which Android requires for BLE scans.

Notification channel IDs and sound IDs are intended to stay stable. Custom reminder sound assets may still need platform provisioning on Android/iOS.

Appwrite Functions define the target account, human household, pairing, and
mounted restoration contract. The backend source implements that contract, but
it is not active in live staging. Prescriptions, schedules, dose state/history,
inventory, and related medication data remain local in Drift/SQLite. No
medication-data sync or upload is introduced. Appwrite/auth outages must not
block the local Robot shell, and mounted credentials do not save, swap, or
restore a human session.

## Appwrite setup

Configured Android builds require four public values from the ignored `.env`
file:

```text
APPWRITE_ENDPOINT
APPWRITE_PROJECT_ID
APPWRITE_CREATE_PAIRING_CODE_FUNCTION_ID
APPWRITE_CLAIM_ROBOT_FUNCTION_ID
```

Personal household management additionally uses these public Function IDs when
that feature is configured:

```text
APPWRITE_CREATE_ROBOT_FUNCTION_ID
APPWRITE_CREATE_HOUSEHOLD_INVITATION_FUNCTION_ID
APPWRITE_ACCEPT_HOUSEHOLD_INVITATION_FUNCTION_ID
APPWRITE_REMOVE_HOUSEHOLD_MEMBER_FUNCTION_ID
```

The mounted-access mobile follow-up will add
`APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID`. In supported Android Robot builds,
`APPWRITE_CLAIM_ROBOT_FUNCTION_ID` will point to the separate/versioned secure
claim Function; there is no `APPWRITE_CLAIM_ROBOT_SECURE_FUNCTION_ID`. Current
clients do not read `APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID` and remain on the
legacy Function until that follow-up is released, configured, and validated.
The app invokes the pairing Functions; it does not read pairing tables
directly, so database and table IDs stay in the Function environment rather
than Flutter configuration. Never add the server pairing HMAC secret or a
Function dynamic API key to this file. See
[`../../backend/appwrite/README.md`](../../backend/appwrite/README.md) for server
schema and deployment details.

## App distributions

Dosey ships as two fixed Android distributions rather than a runtime mode choice:

- **Dosey Personal:** package `com.sloppybobbert.dosey_app`. It updates the existing Android app in place, requires sign-in, and owns the only Android Appwrite OAuth callback. iOS always uses Personal behavior.
- **Dosey Robot:** package `com.sloppybobbert.dosey_app.robot`. It is Android-only, works locally without sign-in, and has no OAuth callback or account actions. It retains schedule, carousel, history, household, and other management features. It uses soft in-app navigation and screen-awake guardrails, not device-owner or lock-task kiosk provisioning.

The phone is the brain. It handles schedules, medication data, refill logic, dose history, PIN, caregiver logic, UI, reminders, Bluetooth commands, and future cloud, voice-command, or local AI features. The XIAO should only execute hardware actions and report status.

The build profile is authoritative. Imported or stale local role settings cannot enable Robot capabilities in Personal or disable them in Robot.

## Local configuration

`.env` is ignored and must be bootstrapped separately in every checkout or worktree. Never commit it or print its values. It must contain the four required public Appwrite keys listed above, plus the optional public Function IDs for features enabled in that build, and must not contain `DOSEY_BUILD_PROFILE`; each build command supplies the profile explicitly.

Personal Android Google/Appwrite sign-in requires the existing package and callback scheme to remain registered in Appwrite. Robot does not support OAuth. App-owned non-OAuth robot pairing remains available when its public Function configuration is present.

## Android package migration

Personal keeps the old package and its app-private Drift database. Robot uses a separate Android sandbox and cannot automatically inherit data from the old shared-package installation.

To migrate non-sensitive prototype data, export a backup from the old/Personal installation before uninstalling anything, install Dosey Robot side by side, then import the backup from Settings. Verify prescriptions, schedules, carousel slots, app settings, dose history, and admin audit history after import. Device role is intentionally not portable and cannot override the destination build profile. Uninstalling before export loses app-private data.

The package migration still requires a physical Android exercise. Until that is recorded, treat a new Robot installation as a clean start and do not assume automatic migration.

## What works locally

- Create, edit, and delete local prescriptions and reminders.
- Track remaining doses, refill thresholds, refill warnings, and refill-add history locally.
- Assign reminders to Daviky carousel slots and exercise controller flows with either the simulator or the compile-tested BLE bench path.
- Run the Guided Trial against deterministic simulator scenarios for successful dispensing, missed-dose recognition, and offline/reconnect behavior.
- Log Today actions separately for dispense success, dose visible, taken confirmations, already taken, early/late taken, snooze, skip, missed, and caregiver help.
- Prevent duplicate terminal Today actions from double-logging the same dose or spending inventory twice.
- Store device role, safety acknowledgement, cached auth state, Action PIN state, refill data, carousel state, household/profile metadata, admin audit events, and dose log events locally.
- Return mounted Robot Mode to Robot Face after 1, 2, 5, 10, or 15 minutes of inactivity, with 2 minutes as the default; pause the timer in the background and defer it while a dialog or sheet is open.
- Route local dose reminders to Robot Face in Robot Mode and Today in Personal Mode, route shortage alerts to Carousel, and run missed-dose reconciliation when the app resumes.
- Sign in with Google through Appwrite for Personal use, generate an owner-authorized ten-minute pairing code, and claim a robot from the mounted Android phone with a dedicated anonymous device identity. Current clients use legacy Team-backed restoration; the pending secure follow-up will restore through `get-mounted-robot` without adding the mounted account to Teams.
- Run Android debug APK and iOS no-codesign debug builds on this machine.

The app must not mark a dose taken because the servo moved. Dispense logging requires a controller success event, and the app separately tracks dose visible and dose taken confirmation.

## Near-term app work

- Physically verify BLE advertising, discovery, status, heartbeat, disconnect, and reconnect with the bare XIAO before attaching external hardware.
- Run mounted-phone manual QA on the Android test device for resume, inactivity, Back, notification, screen-awake, and role-change behavior.
- Keep Today dose actions and refill inventory behavior aligned with local-first safety rules.
- Physically verify the fail-closed heartbeat/offline and reconnect lifecycle for XIAO power loss, crash, disconnect, and missed responses.
- Add server-authorized robot creation, invitations, and seven-account enforcement before exposing broader household management.
- Keep caregiver alerts, medication-data cloud sync, remote push notifications, voice commands, facial recognition, and local AI as later features. The current voice scope is fixed prerecorded WAV phrases only.

## Local commands

Run from this directory:

```sh
flutter pub get
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
flutter analyze
flutter test
flutter run --flavor personal --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal
flutter run --flavor robot --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=robot
flutter build apk --debug --flavor personal --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal
flutter build apk --debug --flavor robot --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=robot
flutter build ios --debug --no-codesign --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal
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
flutter build apk --debug --flavor personal --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal
flutter build apk --debug --flavor robot --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=robot
```

CI writes the four required public values from same-named GitHub repository variables to a temporary `.env`, checks committed whitespace, uploads both debug APKs as short-lived artifacts, and removes the temporary file even after failure. iOS no-codesign builds still run locally.

## Local toolchain notes

- Android SDK: `/opt/homebrew/share/android-commandlinetools`.
- JDK: Homebrew OpenJDK 17.
- Android packages installed: platform-tools, Android SDK Platforms 35 and 36, Build-Tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1.
- Xcode 26.5 is selected at `/Applications/Xcode.app/Contents/Developer`; no-codesign iOS debug builds run locally.
