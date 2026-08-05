# Dosey Appwrite functions

This package contains server-authorized foundations for robot pairing, household
access, mounted-device access, and medication sync. It does not schedule doses,
command dispensing, or replace the phone's local medication store.

Dosey is a non-medical prototype. The phone owns medication, schedules, dose
state, inventory, UI, and caregiver logic. The controller is hardware-only.
Appwrite/auth outages must not block the local Robot shell.

Flutter invokes Functions; it must not read pairing or sync tables directly.
Database and table IDs, Function dynamic API keys, and HMAC secrets remain
server-only. Human authentication, pairing, and hardware authorization are
independent: signing in or out does not alter pairing, hardware authorization,
settings, or local medication data.

The secure mounted-access rollout is inactive. Do not activate or replace the
legacy staging create/claim deployments. Medication-sync Function IDs are future
isolated-staging-only inputs after the activation gates in
[`MEDICATION_SYNC_DEPLOYMENT.md`](MEDICATION_SYNC_DEPLOYMENT.md); those gates are
authoritative for activation. Schema provisioning authority remains the
eight-table template, runtime, and tests. Do not add the IDs to current client,
generated-environment, or workflow configuration. Medication data is local by
default and is not generally cloud-synced.

## Source foundations

- Pairing and household entrypoints are under `src/entrypoints/`.
- `medication-sync-push.ts` and `medication-sync-pull.ts` implement the v1
  Function foundations.
- `appwrite.medication-sync.template.json` defines two additive Functions,
  `medication-sync-push-v1` and `medication-sync-pull-v1`, plus eight
  server-only sync tables:
  `dosey_sync_documents_v1`, `dosey_sync_events_v1`,
  `dosey_sync_help_requests_v1`, `dosey_sync_receipts_v1`,
  `dosey_sync_state_v1`, `dosey_sync_changes_v1`,
  `dosey_sync_terminal_occurrences_v1`, and
  `dosey_sync_terminal_conflicts_v1`.
- The terminal-occurrence and terminal-conflict persistence adapters and tables
  exist, but the push application service does not invoke terminal persistence.
  Every authorized terminal mutation is rejected with
  `TERMINAL_PERSISTENCE_NOT_IMPLEMENTED`; no terminal event, occurrence,
  conflict, receipt, or change is persisted.

Build with `npm ci && npm run build`. Configure each Appwrite Function with the corresponding compiled entrypoint:

```text
dist/entrypoints/create-pairing-code.js
dist/entrypoints/claim-robot.js
dist/entrypoints/create-robot.js
dist/entrypoints/create-household-invitation.js
dist/entrypoints/accept-household-invitation.js
dist/entrypoints/remove-household-member.js
dist/entrypoints/get-mounted-robot.js
dist/entrypoints/medication-sync-push.js
dist/entrypoints/medication-sync-pull.js
```

Use Node.js 22 or newer. The template contains placeholders, not deployable
project credentials or IDs.

## Pairing and household setup

TablesDB is the server-only authority for these six pairing and household
tables: `pairing_claims`, `pairing_attempts`, `mounted_robot_access`,
`robot_installations`, `human_robot_links`, and `household_invitations`.
Appwrite Teams are the household projection. On the secure path, a mounted
anonymous Robot account is authorized only by its exact
`mounted_robot_access` row and must not be dual-written into a Team.

Every Function needs `DOSEY_DATABASE_ID`. `create-pairing-code` and
`claim-robot` also need `DOSEY_PAIRING_CLAIMS_TABLE_ID`,
`DOSEY_PAIRING_ATTEMPTS_TABLE_ID`, and `DOSEY_PAIRING_HMAC_SECRET`;
`claim-robot` additionally needs `DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID`.
`get-mounted-robot` needs `DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID` and
`DOSEY_ROBOT_INSTALLATIONS_TABLE_ID`. The four household Functions
(`create-robot`, `create-household-invitation`,
`accept-household-invitation`, and `remove-household-member`) need
`DOSEY_ROBOT_INSTALLATIONS_TABLE_ID`, `DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID`,
`DOSEY_HOUSEHOLD_INVITATIONS_TABLE_ID`, and
`DOSEY_HOUSEHOLD_INVITATION_HMAC_SECRET`.

Keep the pairing and household HMAC secrets separate, at least 32 random
characters each, and only in Function environments. Never reuse, log, or
expose them, table/database IDs, or Function dynamic API keys to Flutter.

Required Appwrite scopes are `rows.read`, `rows.write`, and `teams.read` for
`create-pairing-code` and `claim-robot`; `rows.read` for
`get-mounted-robot`; and `rows.read`, `rows.write`, `teams.read`, and
`teams.write` for each household Function. Function execution requires an
authenticated Appwrite user: the secure operations separately require the
appropriate verified configured human account or authenticated anonymous
mounted-device account.

Legacy create/claim staging deployments remain active for installed clients.
Secure mounted access is inactive until mounted mobile compatibility,
legacy-device inventory, controlled staging rollout, and two-device validation
are complete. Keep the legacy deployment available for compatibility; do not
use its Team-writing behavior as a secure-path rollback or dual-write mounted
accounts into Teams.

## Deployment boundary

`appwrite.medication-sync.template.json` is additive and is for an isolated
staging project only. Do not apply it directly to production. Its current source
of truth is the template, runtime, and tests. The schema section in
[`MEDICATION_SYNC_DEPLOYMENT.md`](MEDICATION_SYNC_DEPLOYMENT.md) is stale: it
lists only the original six tables and is not provisioning authority. Deployment
and staging remain inactive until product-boundary approval, atomic
terminal-outcome protection, isolated-staging authorization, real two-client
concurrency validation, and secure mounted-rollout approval are complete.

## Verification

```bash
npm ci
npm test
npm run typecheck
npm run build
```

Flutter cloud configuration requires only the public endpoint, project ID, and
Function IDs. Database IDs, table IDs, and HMAC secrets stay in the Function
environment; the app never reads the server-only tables directly.

Unit tests exercise concurrency conflicts and partial Team-operation recovery
through deterministic adapters. They do not prove behavior against a live
Appwrite project. Before release, use an isolated development project to test
creation recovery, concurrent seventh/eighth acceptance, membership failure
recovery, removal recovery, and table permissions. Never run those scenarios
against production data.

The iOS URL scheme in `../../mobile_app/dosey_app/ios/Runner/Info.plist` must remain
`appwrite-callback-<APPWRITE_PROJECT_ID>`. Android derives the same scheme from
the ignored `.env` file at build time; update the iOS value manually if the
Appwrite project changes.
