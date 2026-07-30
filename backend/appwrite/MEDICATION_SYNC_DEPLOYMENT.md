# Medication sync v1 deployment

This runbook applies only to an isolated Appwrite staging project. The checked-in
template is additive and does not contain credentials. Do not target production.

## Before deployment

1. Run `npm ci`, `npm test`, `npm run typecheck`, and `npm run build` from
   `backend/appwrite`.
2. Copy `appwrite.medication-sync.template.json` outside the repository and
   replace only `<APPWRITE_ENDPOINT>`, `<APPWRITE_PROJECT_ID>`,
   `<DOSEY_DATABASE_ID>`, `<DOSEY_HUMAN_ROBOT_LINKS_TABLE_ID>`,
   `<DOSEY_MOUNTED_ROBOT_ACCESS_TABLE_ID>`, and
   `<DOSEY_ROBOT_INSTALLATIONS_TABLE_ID>`.
3. Confirm the target project is disposable staging and the existing
   `human_robot_links` table uses account ID as row ID with `robotId`, `role`, and
   `status` columns.
4. Keep `DOSEY_HUMAN_AUTH_PROVIDERS=google`. Enable `email` only after a staging
   Function proves the current Appwrite session reports provider `email` and a
   verified email. Never add `anonymous` to this human-provider allowlist;
   claimed Robot sessions use the separate anonymous identity verifier.

## Additive apply

Use the Appwrite CLI version approved for the target project. Validate the copied
JSON before running the CLI's table/function push commands. Apply tables first,
wait for every column and index to become available, then apply Functions. The
template creates:

- `dosey_sync_documents_v1`
- `dosey_sync_events_v1`
- `dosey_sync_help_requests_v1`
- `dosey_sync_receipts_v1`
- `dosey_sync_state_v1`
- `dosey_sync_changes_v1`
- `medication-sync-push-v1`
- `medication-sync-pull-v1`

All six tables have empty client permissions. Both Functions execute for signed-in
users but authenticate the forwarded user JWT. Humans require the exact active
`human_robot_links` row. Claimed anonymous Robots require exactly one matching
`mounted_robot_access` row for the requested Robot.

## Required staging gates

Do not release client Function IDs until all gates pass:

1. Google owner and member calls authenticate. A claimed anonymous Robot may
   pull and append dose events only for its exact Robot. Unclaimed, revoked,
   inactive-link, duplicate-link, and cross-Robot calls return no data.
2. Members and claimed Robots can append dose events but receive `OWNER_REQUIRED`
   for medication or schedule mutations.
3. Two concurrent first writes to one household produce unique contiguous change
   sequences, with no domain record missing its receipt and immutable change.
4. Repeating the same `(robotId,idempotencyKey)` and normalized mutation returns
   `duplicate`; changing that mutation returns `IDEMPOTENCY_KEY_REUSED` without a
   second write.
5. A write between pull pages is excluded from the captured checkpoint and appears
   in the next pull cycle.
6. Delete changes contain full parser-valid tombstones. Event changes contain full
   parser-valid immutable dose events.
7. Both Function executions return the exact shared v1 response shapes and all
   deployment logs are free of payloads, tokens, and health data.

If concurrent sequence allocation fails, stop. Do not release incremental sync;
fall back to a separately designed snapshot protocol.

## Client-visible Function behavior

Invoke `medication-sync-push-v1` or `medication-sync-pull-v1` synchronously and
JSON-encode the exact shared v1 request as the Appwrite execution body. Read the
Function status from `Execution.responseStatusCode` and JSON from
`Execution.responseBody`.

- `200`: exact `PushResponse` or `PullPage`.
- `400`: `{ "error": "<contract validation code>" }`.
- `401`: `{ "error": "authentication_required" }`.
- `403`: `{ "error": "household_access_denied" }`.
- `405`: `{ "error": "method_not_allowed" }`.
- Unknown server failures remain Function 5xx responses.

Retry transport failures, timeouts, 429, and 5xx with the identical body and
idempotency keys. Refresh the current human or anonymous session and retry a
401 once. A
`RETRYABLE_INTERNAL_ERROR` acknowledgement means only that mutation may be
retried with its same idempotency key. Do not blindly retry 400, 403, 405,
mutation conflicts, or other rejected acknowledgements.

An initial pull sends null cursor and checkpoint. The first response captures a
fixed checkpoint. While `hasMore` is true, send the returned `nextCursor` with that
same checkpoint. Apply a complete page before persisting `nextCursor`. A terminal
page has `nextCursor == checkpoint`.

## Rollback

Rollback is application-only: first disable both `medication-sync-push-v1` and
`medication-sync-pull-v1`, or apply an equivalent server-side write gate. Then
remove the new Function IDs from client staging configuration and restore the
previous client/Functions. Leave all additive tables and their data intact for
diagnosis. Do not delete tables, downgrade rows, or reuse the v1 Function IDs
for an incompatible contract. A later cleanup needs an approved backup,
retention decision, and separate destructive change review.
