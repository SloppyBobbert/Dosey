# Dosey Appwrite functions

This package contains the server-authorized robot pairing and human household
lifecycle foundations. It does not schedule doses, command dispensing, or mark
doses taken.

The development setup uses Appwrite Teams for robot membership and TablesDB as
the authority for pairing and human household lifecycle state. Flutter invokes
Functions for every household mutation and never reads the server-only tables.

## Functions

- `src/entrypoints/create-pairing-code.ts`: creates a ten-minute, single-use pairing code for an authenticated robot owner.
- `src/entrypoints/claim-robot.ts`: lets an authenticated anonymous mounted-device account claim a robot with that code.
- `src/entrypoints/create-robot.ts`: creates or resumes one robot household for a verified Google account.
- `src/entrypoints/create-household-invitation.ts`: replaces an owner's 24-hour email-bound invitation and returns its code once.
- `src/entrypoints/accept-household-invitation.ts`: atomically reserves a human slot before creating the Team membership.
- `src/entrypoints/remove-household-member.ts`: removes a member as the owner, or lets a non-owner member leave.

Build with `npm ci && npm run build`. Configure each Appwrite Function with the corresponding compiled entrypoint:

```text
dist/entrypoints/create-pairing-code.js
dist/entrypoints/claim-robot.js
dist/entrypoints/create-robot.js
dist/entrypoints/create-household-invitation.js
dist/entrypoints/accept-household-invitation.js
dist/entrypoints/remove-household-member.js
```

Use Node.js 22 or newer. Do not expose either function's dynamic API key or the HMAC secret to Flutter.

## Environment

Appwrite supplies the function endpoint, project ID, and dynamic API key. Add these server-only variables to both functions:

```text
DOSEY_DATABASE_ID
DOSEY_PAIRING_CLAIMS_TABLE_ID
DOSEY_PAIRING_ATTEMPTS_TABLE_ID
DOSEY_PAIRING_HMAC_SECRET
DOSEY_ROBOT_INSTALLATIONS_TABLE_ID
DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID
DOSEY_HOUSEHOLD_INVITATIONS_TABLE_ID
DOSEY_HOUSEHOLD_INVITATION_HMAC_SECRET
```

Generate separate pairing and household invitation HMAC secrets with at least
32 random characters each. Store them only in Appwrite Function environment
variables. Never reuse, log, or expose either secret to Flutter.

The dynamic API key needs only `rows.read`, `rows.write`, `teams.read`, and
`teams.write`. Function execution access should require an authenticated
Appwrite user. The mounted phone must use its own anonymous account; the app
replaces an active human session before invoking the claim Function.

## Tables

Create a server-only database with no client row permissions.

`pairing_claims` columns:

| Column | Type | Required |
| --- | --- | --- |
| `robotId` | varchar | yes |
| `codeDigest` | varchar(64) | yes |
| `expiresAt` | datetime | yes |
| `consumedAt` | datetime | no |
| `mountedDeviceAccountId` | varchar | no |
| `failedAttempts` | integer | yes |
| `active` | boolean | yes |

Add a unique index for `codeDigest` and a key index for `(robotId, active)`.
`pairing_claims.failedAttempts` is a compatibility-only legacy column written
as zero. The per-device `pairing_attempts` rows below are authoritative.

`pairing_attempts` columns:

| Column | Type | Required |
| --- | --- | --- |
| `deviceAccountId` | varchar | yes |
| `failedAttempts` | integer | yes |
| `blockedUntil` | datetime | no |

The attempt row ID is the mounted-device account ID. Appwrite transactions make code replacement, consumption, and attempt updates atomic. A new owner-issued code invalidates the previous code. Five failed claims block that device account for fifteen minutes. A consumed code can retry only from the same mounted-device account and only until its original ten-minute expiry, allowing short recovery from a Teams update failure without creating a permanent remount credential.

`robot_installations` columns:

| Column | Type | Required |
| --- | --- | --- |
| `ownerAccountId` | varchar | yes |
| `displayName` | varchar | yes |
| `humanCount` | integer | yes |
| `status` | enum: `provisioning`, `active` | yes |
| `createdAt` | datetime | yes |
| `updatedAt` | datetime | yes |

The row ID is also the robot Team ID. `humanCount` includes the owner but never
the anonymous mounted-device account.

`human_robot_links` columns:

| Column | Type | Required |
| --- | --- | --- |
| `robotId` | varchar | yes |
| `role` | enum: `owner`, `member` | yes |
| `membershipId` | varchar | no |
| `status` | enum: `provisioning`, `active`, `revoking` | yes |
| `createdAt` | datetime | yes |
| `updatedAt` | datetime | yes |

The row ID is the human account ID. `membershipId` must remain nullable while a
Team operation is being recovered. Add a key index for `robotId`.

`household_invitations` columns:

| Column | Type | Required |
| --- | --- | --- |
| `robotId` | varchar | yes |
| `invitedEmail` | varchar | yes |
| `codeDigest` | varchar(64) | yes |
| `expiresAt` | datetime | yes |
| `createdByAccountId` | varchar | yes |
| `consumedAt` | datetime | no |
| `acceptedAccountId` | varchar | no |
| `revokedAt` | datetime | no |
| `createdAt` | datetime | yes |
| `updatedAt` | datetime | yes |

Add a unique index for `codeDigest` and key indexes for `robotId` and
`invitedEmail`. The opaque row ID is deterministic for one robot and normalized
email, so replacing an invitation invalidates the previous code without
reserving a human slot. Plaintext invitation codes must never be stored or
logged.

All four household Functions require an Appwrite user authenticated through a
current verified Google session. Anonymous and other-provider sessions are
rejected. Transactions enforce one robot per human account and a maximum of
seven accepted humans. Appwrite Team operations occur after transactional
reservation and are resumed idempotently on retry.

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

The iOS URL scheme in `ios/Runner/Info.plist` must remain
`appwrite-callback-<APPWRITE_PROJECT_ID>`. Android derives the same scheme from
the ignored `.env` file at build time; update the iOS value manually if the
Appwrite project changes.
