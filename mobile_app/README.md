# Mobile app

Dosey's Flutter workspace is [`dosey_app/`](dosey_app/). Run Flutter commands
from that directory; its README is the canonical reference for local commands.

## Scope

- **Personal Mode** runs on Android. The retained iOS Personal implementation
  is for preservation and compile-regression only; it is not released or
  qualified. Personal phones do not control the mounted XIAO controller.
- **Robot Mode** is Android-only because it runs on the mounted robot phone.
  It is an app-owned, local mode; it does not use device-owner, lock-task, or
  immersive-kiosk provisioning.
- Drift/SQLite on the phone is authoritative for medication, schedules, dose
  history and state, inventory, carousel, controller, and audit data. Local
  reminders, safety flows, simulator, and Guided Trial behavior must continue
  without cloud access.

The phone owns medication and safety decisions. A controller command or
movement never means a dose was Taken. Record delivery/visibility and Taken
separately, and change inventory only after explicit Taken confirmation. A
missed-dose acknowledgement records that the warning was seen; it does not
change dose state or inventory. Never advise double dosing: “This dose was
missed. Follow your prescription instructions or ask your caregiver,
pharmacist, or doctor.”

## Cloud boundary

`CloudConfiguration` reads only public build configuration: the Appwrite
endpoint and project ID, plus public Function IDs. Its pairing predicates are
configuration checks, not production availability. The required Android Robot
`phone-only` runtime creates no cloud gateways and uses disabled cloud
gateways, so pairing/restoration is disabled there. Secure mounted
pairing/restoration remains inactive pending compatible mobile wiring and
rollout. Flutter invokes Functions and must never read server tables directly
or contain table/database IDs, API keys, HMAC values, or other server secrets.

Medication-sync defines satisfy only a dormant `CloudConfiguration` predicate.
Production mobile does not wire a medication-sync gateway: the feature is
default-off and unwired, and setting its flag or Function IDs does not activate
sync. Local medication behavior never depends on cloud availability.

## Commands

See [local commands](dosey_app/README.md#local-commands) and
[CI commands](dosey_app/README.md#ci-commands). Select `personal` or `robot`
and pass `DOSEY_BUILD_PROFILE` explicitly; unflavored commands are not
canonical.

For the portable local-backup contract, see
[`../docs/local_backup_format.md`](../docs/local_backup_format.md).
