# Dosey Appwrite functions

This package contains the server-authorized robot pairing foundation. It does not schedule doses, command dispensing, or mark doses taken.

The deployed development setup uses Appwrite Teams for robot ownership,
TablesDB for pairing state, and two Node.js Functions. Flutter reaches pairing
state only through those Functions.

## Functions

- `src/entrypoints/create-pairing-code.ts`: creates a ten-minute, single-use pairing code for an authenticated robot owner.
- `src/entrypoints/claim-robot.ts`: lets an authenticated anonymous mounted-device account claim a robot with that code.

Build with `npm ci && npm run build`. Configure each Appwrite Function with the corresponding compiled entrypoint:

```text
dist/entrypoints/create-pairing-code.js
dist/entrypoints/claim-robot.js
```

Use Node.js 22 or newer. Do not expose either function's dynamic API key or the HMAC secret to Flutter.

## Environment

Appwrite supplies the function endpoint, project ID, and dynamic API key. Add these server-only variables to both functions:

```text
DOSEY_DATABASE_ID
DOSEY_PAIRING_CLAIMS_TABLE_ID
DOSEY_PAIRING_ATTEMPTS_TABLE_ID
DOSEY_PAIRING_HMAC_SECRET
```

Generate `DOSEY_PAIRING_HMAC_SECRET` with at least 32 random characters. Store it only in Appwrite Function environment variables.

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

## Verification

```bash
npm ci
npm test
npm run typecheck
npm run build
```

Flutter pairing configuration requires only the public endpoint, project ID,
and two Function IDs. Database and table IDs stay in the Function environment;
the app never reads these server-only tables directly.

The current pairing UI supports an existing robot Team: an owner can generate a
short-lived code, and the mounted Android phone can claim it. Server-authorized
robot creation, human invitations, and the seven-account limit remain follow-up
work and must not be implemented through direct client-side Team mutation.

The iOS URL scheme in `ios/Runner/Info.plist` must remain
`appwrite-callback-<APPWRITE_PROJECT_ID>`. Android derives the same scheme from
the ignored `.env` file at build time; update the iOS value manually if the
Appwrite project changes.
