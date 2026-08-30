# Dosey app

Flutter application for the Dosey medication-dispensing companion robot
prototype. Run all Flutter commands in this directory.

## Product boundary

- **Personal Mode** runs natively on Android and in the web app on iOS, iPadOS,
  and computers. Native iOS source is frozen historical source and is
  unsupported. Personal phones do not control the XIAO.
- **Robot Mode** is Android-only and runs on the mounted robot phone. It is
  local-first, uses app-owned navigation and screen-awake behavior, and does
  not use device-owner, lock-task, or immersive-kiosk provisioning.
- Native Android distribution is through an Android app store or GitHub downloads
  when a release is available. The web app is the supported route on iOS,
  iPadOS, and computers.
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

`APPWRITE_GET_MOUNTED_ROBOT_FUNCTION_ID` is independently optional. Pairing,
household, and medication groups may be omitted, but a present group must be
complete. Profiles require canonical HTTPS `/v1` endpoints and derive the
public callback scheme from the project ID for supported configuration. Native
iOS builds are unsupported; use the web app on iOS, iPadOS, and computers.
Medication sync remains dormant, and staging/production profiles keep it
disabled.

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

Use a checked-in named profile or an isolated public JSON profile. The named
development, staging, and production shells intentionally fail validation until
authoritative public values exist. The wrapper rejects secrets, table IDs, and
unknown keys.

## Local commands

```sh
flutter pub get
dart format .
dart run build_runner build
git diff --exit-code -- lib/core/storage/dosey_database.g.dart
flutter analyze
flutter test
dart run tool/appwrite_profile.dart flutter --profile config/appwrite/offline.json --flavor personal -- run
dart run tool/appwrite_profile.dart flutter --profile config/appwrite/offline.json --flavor robot -- run
dart run tool/appwrite_profile.dart flutter --profile config/appwrite/offline.json --flavor personal -- build apk --debug
dart run tool/appwrite_profile.dart flutter --profile config/appwrite/offline.json --flavor robot -- build apk --debug
git diff --check
```

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
dart run tool/appwrite_profile.dart flutter --profile config/appwrite/offline.json --flavor personal -- build apk --debug
dart run tool/appwrite_profile.dart flutter --profile config/appwrite/offline.json --flavor robot -- build apk --debug
```

For the local backup contract, see
[`../../docs/local_backup_format.md`](../../docs/local_backup_format.md).
