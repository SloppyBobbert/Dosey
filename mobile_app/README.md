# Mobile app

Flutter app workspace for Dosey.

The app lives in `mobile_app/dosey_app/` and keeps Android and iOS personal-phone support in scope. Robot Mode is Android-only because the embedded robot phone is mounted inside Dosey.

## Workspace summary

| Item | Status |
| --- | --- |
| App shell | Today, Medications, and Settings; prescriptions, schedules, and carousel management live within those surfaces, Controller is protected under Robot Maintenance, and Robot Face is the mounted Android surface |
| Local storage | Drift/SQLite on the phone app only |
| Prescriptions and schedules | Local prescriptions, refill inventory tracking, schedule profiles, schedule editing, and enabled state |
| Accounts and robot linking | Personal human authentication for account/household use; guest Robot distribution with current legacy pairing and a pending secure mounted-access follow-up |
| Carousel and controller | Daviky loading workflow, simulator, and compile-tested D1 BLE bench path; bare-XIAO Android BLE connection, safe-default HEARTBEAT, device/config/safety status, LED test, and disconnect indication observed; that bench evidence does not qualify the identified APK or integrated carousel/hardware path; integrated external-hardware lifecycle, reconnect, power-loss, movement cancellation/timeout, and movement/dispensing remain unverified |
| Mounted Robot Mode | Face-first resume and Back behavior, configurable inactivity return, role-aware local notification routing, and screen-awake control only while Robot Face is active and the app is resumed |
| Builds | Mobile CI builds Personal and Robot debug APKs, uploads both as short-lived artifacts, and runs a separate no-codesign iOS debug build |

## Current app

This directory is the Flutter workspace. The app itself lives in `mobile_app/dosey_app/`, which is the canonical place for current app scope and commands.

Current workspace-level status:

- Android and iOS personal-phone support stay in scope. Robot Mode stays Android-only.
- The app shell has Today, Medications, and Settings; prescriptions, schedules, and carousel management live within those surfaces, Controller is protected under Robot Maintenance, and Robot Face is the mounted Android surface. Local storage, refill tracking, reminder flows, the Daviky carousel loading workflow, controller simulator, Guided Trial scenarios, and fixed prerecorded Robot Mode voice prompts are in place.
- Mounted Robot Mode returns to Robot Face on resume and after configurable inactivity, contains Back navigation inside the app, and keeps the display awake only while Robot Face is active and the app is resumed; it does not keep the display awake while backgrounded.
- The D1 controller protocol now has a compile-tested Flutter BLE transport, staged gateway, and foreground Robot Mode heartbeat/reconnect lifecycle. Android-to-bare-XIAO connection, safe-default HEARTBEAT, device/config/safety status, LED test, and disconnect indication were observed. That bench evidence does not qualify the identified APK or integrated carousel/hardware path. Integrated external-hardware lifecycle, reconnect, power-loss, movement cancellation/timeout, and movement/dispensing behavior remain unverified.
- Personal account and household use requires human authentication. The mounted Robot distribution remains fully usable as a guest. Human authentication, device pairing, and hardware authorization are independent; sign-in/sign-out does not change pairing, hardware authorization, settings, or local medication data, and pairing does not alter human authentication.
- The target mounted-access contract uses server-only `mounted_robot_access` and `get-mounted-robot`; it is not active in live staging. Current-main Android clients still use legacy Team-backed restoration and do not read `APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID`. Anonymous mounted accounts must never enter Teams on the secure path; Teams remain for human household ownership and membership.
- A pending mobile follow-up will add `APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID`, point `APPWRITE_CLAIM_ROBOT_FUNCTION_ID` at a separate/versioned secure Function for supported Android Robot builds, and restore through `get-mounted-robot`. Until it is released, configured, and validated, legacy clients stay on the legacy Function. Do not dual-write mounted accounts to Teams. The target contract is seven server-authorized Functions and six server-only TablesDB tables. Medication schedules, dose state/history, inventory, and related medication data remain local Drift/SQLite; no medication cloud sync or upload is introduced.
- Appwrite/auth outages must not block the local Robot shell, and mounted credentials never replace or multiplex a human session.
- First physical test device: 2024 Moto G Play.

## Target app direction

Robot Mode on the mounted Android phone handles the face screen, reminders, dispense UI, missed-dose recognition, hardware test screen, refill status, dose history, fixed prerecorded voice prompts, quiet-hours behavior, and soft in-app mounted-phone guardrails. Android device-owner, lock-task, and immersive kiosk provisioning remain out of scope.

Voice commands and local AI remain future work.

Personal Mode should handle patient or caregiver notifications, missed dose/refill alerts, dose history, and medication schedule editing when permissions allow.

The phone owns medication schedules, medication data, refill logic, PIN rules, caregiver logic, and dose states. The XIAO should only execute and report hardware actions.

For detailed feature coverage, local behavior, and app-specific commands, see [`dosey_app/README.md`](dosey_app/README.md).

Run Flutter commands from `mobile_app/dosey_app/`.

## Commands

Use the canonical [local commands](dosey_app/README.md#local-commands) and
[CI commands](dosey_app/README.md#ci-commands) in the app README. Select a
build flavor and `DOSEY_BUILD_PROFILE` explicitly; unflavored APK commands are
not canonical.

The ignored `dosey_app/.env` contains the six public Function configuration names
currently present in source, plus the public endpoint and project ID. The
pending mobile follow-up will add `APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID` and
point the existing `APPWRITE_CLAIM_ROBOT_FUNCTION_ID` at a separate/versioned
secure Function for supported Android Robot builds. There is no separate secure
claim configuration key today. Until that follow-up is released, configured,
and validated, keep current clients on the legacy Function. Database/table IDs,
dynamic API keys, and HMAC secrets stay in the Function environment. Web remains
auth-only, and no server credential belongs in the Flutter environment.

Android SDK platforms 35 and 36 and OpenJDK 17 are configured locally for the first Moto G Play builds. Xcode 26.5 is configured for local iOS no-codesign builds.

## CI

GitHub Actions runs [Mobile CI](../.github/workflows/mobile-ci.yml) for pull
requests and pushes to `main`. Its Ubuntu job checks committed whitespace,
generated Drift code, formatting, analyzer output, and tests, then builds and
uploads short-lived Personal and Robot debug APK artifacts. Its macOS job runs
the separate no-codesign iOS debug build. These artifacts are not releases.
