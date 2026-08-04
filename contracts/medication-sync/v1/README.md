# Medication Sync Contract v1

This directory is the language-neutral wire contract shared by the Dosey
Android app, Appwrite Functions, and caregiver web app. The JSON fixtures are
the executable source of truth. Dart and TypeScript parsers must accept every
case in `fixtures/valid.json` and reject every case in
`fixtures/invalid.json`.

## Trust and authorization boundary

- `contractVersion` is the integer `1` on every resource, envelope, mutation,
  acknowledgement, conflict, and nested `OccurrenceRef`. Mutation payloads do
  not add another version field around their writeable fields.
- Authentication plus the active principal-to-robot authorization record for the
  exact `robotId` are authoritative. Roles remain `owner` and `member`; clients
  never send a role in a mutation. The server derives account, role, and scope.
- `member` is the existing wire value for a caregiver. It is retained for
  compatibility; no wire rename or migration is implied. Owners and caregivers
  may create, edit, tombstone, and observe medication and schedule plans.
- Human actors, including owners and caregivers, may not append terminal dose
  outcomes. Only an authenticated registered patient-side device authority may
  upload `taken_confirmed`, `skipped`, or `missed`; its server-derived registered
  device ID must exactly match the mutation `deviceId`.
- These are normative contract decisions. Service/store enforcement is deferred
  to #116; production medication sync remains disabled in this slice.
- IDs are opaque, non-empty strings of at most 128 characters, except the
  deterministic `OccurrenceRef.occurrenceId`, which may be at most 256
  characters. They must not have leading or trailing whitespace.
- Integers are limited to JavaScript's exactly representable safe-integer
  range. Timestamp years are `0001..9999`.
- Timestamps are RFC 3339 UTC strings ending in `Z`. `scheduledAt` is
  normalized to exactly `YYYY-MM-DDTHH:mm:ss.SSSZ` before occurrence identity
  is derived.
- Parsers reject unknown fields. A future additive wire change therefore
  requires a new contract version or a coordinated v1 fixture update.

## Records

### Medication

`Medication` contains `id`, `householdId`, `name`, `pillType`, nullable
`instructions`, positive `revision`, nullable `deletedAt`, and `updatedAt`.
`pillType` is `pill`, `capsule`, or `tablet`. Inventory is intentionally local
to Android and is not part of this contract.

### Daily schedule

`Schedule` contains `id`, `householdId`, `medicationId`, `label`, `hour`
(`0..23`), `minute` (`0..59`), non-empty IANA `timezoneId`, `enabled`, positive
`revision`, nullable `deletedAt`, and `updatedAt`. V1 supports one local wall
clock time every day; weekly and complex recurrence are deferred.

`canonical-timezones.json` is the versioned, case-sensitive timezone
source-of-truth. It contains the canonical `Zone` records from IANA tzdb 2026b
(`2026b-rearguard` source, with its SHA-256 recorded in the artifact), plus the
contract compatibility name `UTC`. IANA `Link` aliases and case variants are
excluded. The generated TypeScript and Dart sets mirror this artifact exactly;
Dart uses the already-locked `timezone` package's `latest_all` database for
offset conversion. To update the set, obtain an official IANA `tzdata.zi` and
run the artifact's recorded `generationCommand`. Commit the artifact and both
generated mirrors together, then run both parity suites. The generator itself
is `generate-timezones.mjs` and has no package dependency. It validates and
prepares every requested output before writing, stages replacements beside
their targets, awaits every staging write before cleanup, and uses per-file
atomic renames with rollback. A filesystem cannot atomically rename multiple
files as one transaction, so all backups remain available until every target
replacement succeeds. That success is the commit point: an earlier failure
restores every original and removes temporary files, while a later backup
cleanup failure leaves every new target installed and retains the affected
collision-safe backup for recovery.

The name artifact and the runtime transition databases are distinct. At the
time v1 was frozen, the artifact came from IANA 2026b-rearguard, the deployed
Node ICU reported tzdb 2026a, and Dart `timezone` 0.10.1 bundled tzdb 2025b.
`Factory` is treated as a fixed zero-offset compatibility zone in TypeScript so
it matches Dart. UTC `scheduledAt` and the stable occurrence ID are
authoritative; `localDate` and `timezoneId` are validated metadata. Exact
cross-runtime behavior at every timezone rule edge is therefore a deployment
compatibility constraint, not a mathematical guarantee of this artifact. Both
runtimes must pass the representative DST fixtures and ordinary-date
occurrence conversion for every canonical zone before release; any observed
fixture mismatch blocks deployment. Updating a runtime timezone database
requires rerunning those checks against the other runtime.
If any other canonical identifier is absent from a deployed runtime database,
the parser rejects it with `UNSUPPORTED_TIMEZONE_DATABASE`; raw runtime lookup
errors are not part of the wire contract.

### Occurrence reference

`OccurrenceRef` identifies one scheduled wall-clock occurrence. Its ID is
exactly:

```text
<scheduleId>:<scheduleRevision>:<scheduledAt>
```

where `scheduledAt` is the canonical UTC value carried in the parsed record.
The record also carries `localDate` (`YYYY-MM-DD`) and `timezoneId`; parsers
must verify that converting `scheduledAt` into that IANA timezone produces the
claimed local date. The schedule ID and revision in the ID must exactly match
the record. Occurrences are generated by clients and are not a server table in
v1.

### Explicit dose event

`DoseEvent` is immutable and contains `id`, `householdId`, `medicationId`, an
`OccurrenceRef`, `kind`, `occurredAt`, and `actorAccountId`. Allowed kinds are
`taken_confirmed`, `skipped`, `missed`, `snoozed`, and `help_requested`.
Only `taken_confirmed` means taken. There is no `marksDoseTaken` field, and
controller movement or visibility is never a dose event.

The server derives the authenticated actor. Mutation payloads containing a
client-supplied `actorAccountId` are rejected as unknown fields.

`taken_confirmed`, `skipped`, and `missed` are mutually exclusive terminal
outcomes for a canonical occurrence ID. An exact terminal mutation replay is a
duplicate. A changed replay with the same terminal outcome is
`TERMINAL_OUTCOME_REPLAY_MISMATCH`; a different terminal outcome is
`TERMINAL_OUTCOME_CONFLICT`; both require review. These are contract decisions,
not a storage or transaction implementation. Occurrence-level atomic exclusion
and Taken/Skipped authority are not enforced in this slice. `missed` has no
inventory mutation semantics. A missed acknowledgement, if represented later,
remains separate from the terminal outcome and never changes inventory.

### Deferred inventory adjustment ledger

The storage-neutral `InventoryAdjustment` shape reserves `ledgerId` (immutable
ledger identity), `medicationId`, signed `delta`, `actorId`, `reason`, and
`idempotencyKey`. Persistence and inventory services are deferred. In
particular, `missed` never creates an inventory adjustment.

### Mutation and idempotency

`Mutation` contains `mutationId`, `deviceId`, `idempotencyKey`, `entityType`,
`operation`, `entityId`, nullable `baseRevision`, and `payload`.

- Medication and schedule `upsert` payloads contain client-writeable fields
  but no `householdId`; the request `robotId` supplies server-verified scope.
  `baseRevision` is `null` for create and a positive revision for update.
- Medication and schedule `delete` requires a positive `baseRevision` and a
  `null` payload.
- A dose event uses `append`, has `baseRevision: null`, and carries only
  `medicationId`, `occurrence`, `kind`, and `occurredAt`. The server uses
  `entityId` as the event ID and supplies `householdId` and `actorAccountId`.
- A replay with the same idempotency key and semantically identical mutation
  in the same `robotId` scope is a duplicate. Idempotency storage identity is
  the pair `(robotId, idempotencyKey)`. Reusing that pair with any changed
  mutation field is rejected with `IDEMPOTENCY_KEY_REUSED`; the same key in a
  different robot scope is independent.
- Medication and schedule writes use compare-and-swap revisions. Conflicts are
  returned to the client and are never silently merged.

### Acknowledgements, conflicts, and pull pages

The push Function accepts `PushRequest { contractVersion, robotId, operations }`
and returns `PushResponse { contractVersion, robotId, acknowledgements }`. The
pull Function accepts `PullRequest { contractVersion, robotId, cursor,
checkpoint, limit }`. `limit` is `1..100`; cursor and checkpoint are nullable
only on the first request. Both Functions authenticate the calling principal,
strictly parse the request, and resolve active access for the parsed `robotId`
before applying any operation or returning scoped data.

Cursor and checkpoint wire values are strings so JSON cannot round large
integers, but their content is numeric: canonical non-negative base-10
safe-integer spelling (`0` or `[1-9][0-9]*`, maximum
`9007199254740991`). `limit` is an integer from `1` through `100`; a push has at
most 100 operations. The initial pull sends both cursor and checkpoint as null.
Integral JSON numbers are accepted whether a runtime decoder represents them
as integer or floating-point values. Fractional, non-finite, and unsafe values
are rejected, and negative zero is normalized to zero.
Later pulls send both. The checkpoint is the stable inclusive high-water mark
for one traversal. A page satisfies `cursor <= nextCursor <= checkpoint`, its
change cursors are strictly increasing after the requested cursor and do not
exceed `nextCursor`, and `hasMore: true` requires `nextCursor < checkpoint`.
The server may advance `nextCursor` past the final returned change when it has
scanned filtered log entries.

`MutationAck.outcome` is `applied`, `duplicate`, `conflict`, or `rejected`.
Applied and duplicate acknowledgements require a cursor, allow a nullable
revision, and have no error or conflict. Conflict acknowledgements carry only
their `Conflict` in addition to identity and outcome; revision, cursor, and
error are null. Rejected acknowledgements require an `errorCode` and have null
revision, cursor, and conflict. These acknowledgements report mutation sync
receipt/outcome/cursor only. In particular, a `help_requested` dose event is
open-only in v1: acknowledging its mutation does not resolve the help request,
and help acknowledgement/resolution is deferred to a later contract.

`PullPage` contains `robotId`, the requested nullable cursor, the stable numeric
string `checkpoint`, the next numeric string cursor, `hasMore`, and ordered
changes. The page
`robotId` must match the pull request, and every authoritative medication,
schedule, dose event, or tombstone record must carry that same value as its
server-derived `householdId`. Each change has its own cursor. Clients persist
`nextCursor` only after applying the complete page.
Nonterminal pages must strictly advance `nextCursor`; terminal pages must set
`nextCursor == checkpoint` so a client cannot stop before the stable high-water
mark.

Every conflict has different expected and actual revisions. A push response
must bind every nested authoritative conflict record to its own `robotId`, just
as pull pages bind every returned record to their robot scope.

Android persists enough normalized outbox state to reconstruct a complete,
parser-valid `Mutation`, including its mutation-level `contractVersion` and any
nested `OccurrenceRef.contractVersion`. The storage representation may be
normalized columns rather than one JSON blob, but deterministic reconstruction
must survive a parser/serializer round trip without losing fields. Transport
places the reconstructed mutations in `PushRequest.operations`; a payload by
itself is not a valid outbox operation.

The public Dart reconstruction path is:

```dart
final normalized = normalizeMedicationSyncMutationJson(reconstructedColumns);
final mutation = MutationContract.fromJson(normalized);
final requestJson = MedicationSyncPushRequest(
  robotId: robotId,
  operations: [mutation],
).toJson();
```

`MutationContract.fromJson` rejects incomplete reconstruction and `toJson`
emits normalized nested occurrences. Re-normalizing normalized output must
produce structurally identical JSON (use deep comparison, not Dart `Map.==`).

## Appwrite Function adapters

The adapter temporarily rejects a contract-valid `missed` event with
`MISSED_EVENT_NOT_IMPLEMENTED` before append conversion. This transitional
fail-closed gate does not add service/store enforcement for terminal outcomes.

The TypeScript adapter parses untrusted JSON with `parsePushRequest` or
`parsePullRequest`. These functions return `PushRequest` and `PullRequest`
respectively and throw `MedicationSyncContractError { code, path, message }`.
Adapters catch only that class to produce their invalid-request response;
unknown exceptions remain server errors. After authentication, the adapter
loads active principal access for the parsed `robotId`, derives account,
role/device, and household scope, and applies normalized values. It never maps
a client body field into authoritative account, role, device, or household
columns.

Push request JSON:

```json
{"contractVersion":1,"robotId":"robot-1","operations":[{"contractVersion":1,"mutationId":"mutation-1","deviceId":"android-1","idempotencyKey":"android-1:mutation-1","entityType":"medication","operation":"delete","entityId":"medication-1","baseRevision":3,"payload":null}]}
```

Push response JSON:

```json
{"contractVersion":1,"robotId":"robot-1","acknowledgements":[{"contractVersion":1,"mutationId":"mutation-1","outcome":"applied","revision":4,"cursor":"1042","errorCode":null,"conflict":null}]}
```

Initial and subsequent pull request JSON:

```json
{"contractVersion":1,"robotId":"robot-1","cursor":null,"checkpoint":null,"limit":100}
{"contractVersion":1,"robotId":"robot-1","cursor":"1042","checkpoint":"1100","limit":100}
```

The pull Function returns the exact `PullPage` JSON shape exercised by
`fixtures/valid.json`: `contractVersion`, `robotId`, nullable `cursor`, numeric
string `checkpoint` and `nextCursor`, `hasMore`, and ordered `changes`.

For idempotency storage, call
`canonicalMutationHashInput(request.robotId, mutation)`. It reparses and
normalizes the mutation, includes the validated robot scope, recursively sorts
object keys by case-sensitive UTF-16 code-unit order, preserves array order,
and emits compact JSON. TypeScript and Dart exercise the same ordering,
including non-ASCII and surrogate-pair keys. The server computes SHA-256 over
the UTF-8 bytes of that returned string. The database lookup key
remains `(robotId, idempotencyKey)`; the hash detects changed replays. Hashes,
canonical payload JSON, actor IDs, household IDs, revisions, and cursors are
always server-derived. Client claims for any hash or authoritative field are
never accepted or compared as trusted values.
Accepted spellings of the dose-event mutation `occurredAt` instant are
normalized to `YYYY-MM-DDTHH:mm:ss.SSSZ` before this hash input is generated, so
equivalent UTC spellings do not create changed-replay failures.

## Canonical safety examples

`fixtures/valid.json` includes the canonical changed-payload rejection ack and
records for each entity and operation. `fixtures/invalid.json` covers role
injection, `marksDoseTaken`, unsupported dose kinds, invalid CAS revisions,
malformed occurrence IDs, non-UTC timestamps, invalid cursors, and unknown
fields.
