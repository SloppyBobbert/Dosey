# Appwrite staging handoff

## Scope and status legend

This record covers staging-only Appwrite and web validation. It is not proof of
physical hardware operation or production readiness.

| Status | Meaning |
| --- | --- |
| **Verified** | Confirmed by recorded validation. |
| **Failed then resolved** | An attempt failed and the correction was verified. |
| **Pending** | Required validation has not finished. |
| **Local-only risk** | Evidence exists only in the local worktree. |

Production data, DNS, secrets, and provider credentials remain untouched.
Medication schedules, doses, history, and inventory remain local Drift data.
Pairing does not sync medication data or imply that a dose was taken.

## Project and Site

| Item | Value |
| --- | --- |
| Project | `Dosey Development` (`6a66b014000547ba3892`) |
| Region | SFO |
| Endpoint | `https://api.dosey.dev/v1` |
| Observed Appwrite | `1.9.5` |
| Staging Site | `dosey-web-staging` (`6a681899000175fa24ce`) |
| Custom domain | `https://staging.dosey.dev` |
| Generated domain | `dosey-web-staging.appwrite.network` |
| Active/latest deployment | `6a685fb96a88b8ab8976` |
| Ready rollback deployment | `6a6818d2539cca111d56` |

The temporary source-test Site and deployment were not modified during the
final rollout. `dosey.appwrite.network` is not an accepted staging auth origin.

## Acceptance evidence

**Verified:** The user observed all of the following on
`https://staging.dosey.dev`:

- Google OAuth sign-in.
- Email OTP sign-in.
- iPhone Safari Add-to-Home-Screen installation and standalone PWA launch.

**Verified:** Site delivery, web auth, and the standalone PWA work on staging.

## Historical rollout record

**Failed then resolved:** The first activation showed the new deployment ready
on all edges, but an immediate custom-domain probe still served the old
deployment. Verification stopped, and the old deployment was restored once.
Read-only diagnosis found proxy rules mapped directly to deployment IDs. The
candidate URLs served the new content, proving a routing propagation issue.

**Verified:** The candidate deployment was reactivated once. Proxy rules updated
within seconds, and three checks over more than two minutes showed both staging
domains serving the new root page, auth page, JavaScript, assets, and API/CORS
responses.

**Failed then resolved:** OAuth was first tested on the temporary
`dosey.appwrite.network` host, which was not a registered Web platform. The
correction was to use `https://staging.dosey.dev`.

**Failed then resolved:** Google sign-in first returned a redirect mismatch.
The Appwrite callback was confirmed, the exact callback was added by a human in
Google Cloud, and the user then confirmed staging Google OAuth worked.

The Appwrite CLI was initially unavailable. After approved installation,
regional login attempts failed because CLI account authentication was global.
One temporary public-only configuration was created in the dirty checkout,
inspected, and moved to macOS Trash. The successful isolated configuration was
outside the repository and contained no secret values.

## Local secure implementation

The local backend contract is the approved mounted-access architecture:

- Humans remain Appwrite Team members.
- Anonymous Robot accounts never join or enumerate Teams.
- `mounted_robot_access` is a server-only TablesDB table with row ID `robotId`,
  fields `robotId`, `mountedDeviceAccountId`, `pairingClaimId`, `createdAt`, and
  `updatedAt`, plus a unique `mountedDeviceAccountId` index and no client
  permissions.
- `claim-robot` verifies the forwarded JWT with Account, verifies the current
  session user ID and provider, then atomically consumes the claim, resets the
  attempt row, and creates or replaces mounted access.
- `get-mounted-robot` reads mounted access and returns only `{robotId,
  displayName}` for the active installation. It never calls Teams.
- The old Team-writing claim deployment is never a safe rollback target.

**Verified locally:** Backend tests pass `119/119`, and the backend build passes.
Flutter tests pass `1070/1070`, and Flutter analyze passes. The build_runner
check left the generated database file unchanged. A Robot debug APK built
successfully using a temporary public-only `.env`; that file was removed to
macOS Trash. The APK build was compile-only and did not validate undeployed
cloud Functions. Existing non-failing Drift warnings remain informational.

## Current cloud truth

The staging Site, web auth, and PWA are working. The cloud backend remains
unchanged and incomplete: it has only the two outdated active pairing Functions
and the two existing pairing tables. No backend cloud mutations have been made.

The local secure contract expects seven Functions and six server-only tables:
the two pairing tables, `mounted_robot_access`, `robot_installations`,
`human_robot_links`, and `household_invitations`. The local contract is not yet
deployed to staging.

## Worktree and diff status

The secure backend and mobile implementation is an uncommitted local diff on
branch `fix/appwrite-staging-e2e`. It includes the mounted-access backend,
restore Function, pairing transaction changes, private Flutter mounted-access
state and cache, Robot Settings presentation, tests, and this handoff. The
primary checkout remains dirty and must not be edited.

Integrate the secure code through reviewed Git changes first. Fresh approval is
required before commit, push, PR creation, or merge. Use a reviewer before PR
creation or merge.

## Next staging sequence

1. Review and integrate the secure local code through Git. Do not mutate cloud
   resources in this step.
2. With separate approval, perform the exact staging cloud mutation: preserve
   the two existing tables, create only missing schema, create Functions in a
   disabled state, set variables and scopes before deployment, then use
   readback and wait gates after every change.
3. Activate Functions in dependency order. Do not make a broad push. Do not
   use the old Team-writing claim deployment as a rollback.
4. Run real two-device tests with an owner and anonymous Robot account:
   pairing, remount, restart/restore, duplicate-device rejection, human-Team
   rejection, expiry, cooldown, conflict, and database-integrity failures.

No cloud mutation, commit, push, PR, or merge is approved by this record.

## Preserved local validation history

The simulator scenario harness remains a separate local worktree with no commit
or push. Its first tests used local pause/resume seams and were rejected. The
real reconciliation flow then hung during simulator close with a stream teardown
error. Ordered asynchronous shutdown, synchronous clock close, and producer
cleanup resolved the hang. Five harness tests and related suites passed; those
tests do not prove physical hardware or BLE movement.

Hardware remains local-only. The repository-relative tracker is
`docs/hardware_status_and_next_steps.md`; it is ignored and is not Git-backed.
