# Dosey app

Flutter application for the Dosey medication-dispensing companion robot
prototype. Run all Flutter commands in this directory.

## Product boundary

- **Personal Mode** runs on Android. The iOS Personal implementation is
  retained only for preservation and compile-regression; it is not released or
  qualified. Personal phones do not control the XIAO.
- **Robot Mode** is Android-only and runs on the mounted robot phone. It is
  local-first, uses app-owned navigation and screen-awake behavior, and does
  not use device-owner, lock-task, or immersive-kiosk provisioning.
- Drift/SQLite is the authoritative local store for medication, schedules,
  dose history and state, inventory, carousel, controller, and audit data.
  Local reminders and core safety behavior work without cloud access.

The phone—not the controller—owns medication and dose state. Movement or a
successful controller command does not mean a dose was Taken. Track movement,
visibility, Taken, skipped, missed, and error states separately; change
inventory only after explicit Taken confirmation. A missed-dose acknowledgement
only records that the warning was seen. It does not change dose state or
inventory. Never advise double dosing: “This dose was missed. Follow your
prescription instructions or ask your caregiver, pharmacist, or doctor.”

## Cloud configuration

`CloudConfiguration` accepts public Dart defines only. `APPWRITE_ENDPOINT` and
`APPWRITE_PROJECT_ID` must be supplied together. The pairing predicate requires
both of these Function IDs, but it is not a production-availability guarantee:

```text
APPWRITE_CREATE_PAIRING_CODE_FUNCTION_ID
APPWRITE_CLAIM_ROBOT_FUNCTION_ID
```

Household management additionally requires all of these public Function IDs:

```text
APPWRITE_CREATE_ROBOT_FUNCTION_ID
APPWRITE_CREATE_HOUSEHOLD_INVITATION_FUNCTION_ID
APPWRITE_ACCEPT_HOUSEHOLD_INVITATION_FUNCTION_ID
APPWRITE_REMOVE_HOUSEHOLD_MEMBER_FUNCTION_ID
```

Medication-sync defines satisfy only a dormant `CloudConfiguration` predicate:
`CAREGIVER_SYNC_ENABLED=true`, endpoint/project configuration, and both IDs
below. They are future isolated-staging-only inputs after the authoritative
activation gates in the backend deployment guidance, not current mobile
configuration. The backend template, runtime, and tests—not the runbook's stale
schema section—are authoritative for provisioning. Production mobile does not
wire a medication-sync gateway, so these values do not activate sync. The
feature remains default-off and unwired.

```text
APPWRITE_MEDICATION_SYNC_PUSH_FUNCTION_ID
APPWRITE_MEDICATION_SYNC_PULL_FUNCTION_ID
```

Flutter calls Functions; it never reads server tables directly. Do not put
database/table IDs, dynamic API keys, HMAC secrets, or any other server
credential in `.env` or a Dart define. Cloud/auth outages must not block local
medication, reminder, Robot Mode, or safety behavior.

The required Android Robot `phone-only` runtime does not create cloud gateways
and uses disabled cloud gateways, including for pairing. Secure mounted
pairing/restoration remains inactive pending compatible mobile wiring and
rollout. Do not treat configured Function IDs as an available mounted-phone
feature.

`.env` is ignored. Bootstrap it separately for each checkout/worktree, never
commit or print it, and pass it only through `--dart-define-from-file=.env`.

## Local commands

```sh
flutter pub get
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
flutter analyze
flutter test
flutter run --flavor personal --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal --dart-define=DOSEY_RUNTIME_CAPABILITY=hardware-assisted --dart-define=CAREGIVER_SYNC_ENABLED=false
flutter run --flavor robot --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=robot --dart-define=DOSEY_RUNTIME_CAPABILITY=phone-only --dart-define=CAREGIVER_SYNC_ENABLED=false
flutter build apk --debug --flavor personal --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal --dart-define=DOSEY_RUNTIME_CAPABILITY=hardware-assisted --dart-define=CAREGIVER_SYNC_ENABLED=false
flutter build apk --debug --flavor robot --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=robot --dart-define=DOSEY_RUNTIME_CAPABILITY=phone-only --dart-define=CAREGIVER_SYNC_ENABLED=false
flutter build ios --debug --no-codesign --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal
git diff --check
```

The iOS command builds the retained Personal implementation for preservation
and compile-regression only; it is not release or qualification evidence.

## Android package migration

Personal and Robot have separate Android package IDs and app sandboxes. Before
uninstalling the Personal app or clearing its data, export a backup and keep it
in trusted transfer storage. Retain one trusted transfer copy until restore or
import is verified, then delete unneeded copies. Where possible, install Robot
side-by-side, then import the backup from Settings and verify prescriptions,
schedules, carousel slots, app settings, dose history, and audit history.
Device role and runtime capability do not transfer; the destination build keeps
its configured capability.

Remote-sync checkpoints are skipped and not separately backed up. Restored
`local_only` pending work is reset for a fresh attempt; restored bound `pending`
or `in_flight` work is quarantined as `permanent_failure` with
`restore_review_required`. This cannot satisfy or activate production sync.

## CI commands

```sh
flutter pub get
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --flavor personal --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=personal --dart-define=DOSEY_RUNTIME_CAPABILITY=hardware-assisted --dart-define=CAREGIVER_SYNC_ENABLED=false
flutter build apk --debug --flavor robot --dart-define-from-file=.env --dart-define=DOSEY_BUILD_PROFILE=robot --dart-define=DOSEY_RUNTIME_CAPABILITY=phone-only --dart-define=CAREGIVER_SYNC_ENABLED=false
```

For the local backup contract, see
[`../../docs/local_backup_format.md`](../../docs/local_backup_format.md).
