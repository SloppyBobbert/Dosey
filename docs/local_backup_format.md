# Dosey Local Backup Format

Dosey local backups are logical, versioned UTF-8 JSON documents, not SQLite,
WAL, or shared-memory copies. They are plain text and can contain medication,
schedule, dose-history, household-label, and audit data. Handle exported files
as sensitive data.

## Current envelope

New exports use format **v2** and source schema **18**:

```json
{
  "format": "dosey-local-backup",
  "formatVersion": 2,
  "sourceSchemaVersion": 18,
  "data": {}
}
```

The four envelope fields and the `data` fields are exact. The v2 sections, in
canonical order, are:

1. `settings`
2. `scheduleProfiles`
3. `prescriptions`
4. `prescriptionRefills`
5. `reminderSchedules`
6. `carouselSlots`
7. `carouselLoadSessions`
8. `carouselLoadSlotSnapshots`
9. `carouselStates`
10. `medicationShortageAlerts`
11. `doseLogEvents`
12. `controllerCommandSessions`
13. `controllerCommandEvents`
14. `adminAuditEvents`
15. `phoneDoseActionEvents`
16. `syncOutboxMutations`

Imports also accept v1/source-schema-14 documents and normalize a valid v1
document to v2. New exports are always v2/schema 18.

## Portable data

Each section is an array of rows with exact fields and validated primitive
types. Timestamps are UTC integer microseconds since the Unix epoch and must be
whole seconds. `?` marks a nullable field.

| Section | Fields |
| --- | --- |
| `settings` | `key`, `value`, `updatedAt` |
| `scheduleProfiles` | `id`, `name`, `isActive`, `createdAt`, `updatedAt` |
| `prescriptions` | `id`, `name`, `pillType`, `remainingDoses`, `guidedPillIcon`, `availableDoses`, `loadedDoses`, `usedDoses`, `reviewDoses`, `defaultRefillQuantity`, `defaultDoseCountPerDose`, `doseInstructions`, `refillThreshold`, `createdAt`, `updatedAt` |
| `prescriptionRefills` | `id`, `prescriptionId`, `doseDelta`, `remainingAfter`, `occurredAt`, `note?` |
| `reminderSchedules` | `id`, `label`, `prescriptionId?`, `profileId`, `hour`, `minute`, `revision`, `isEnabled`, `createdAt`, `updatedAt` |
| `phoneDoseActionEvents` | `id`, `deviceId`, `occurrenceId`, `scheduleId`, `scheduleRevision`, `scheduledAt`, `localDate`, `timezoneId`, `medicationId`, `kind`, `occurredAt`, `marksDoseTaken`, `idempotencyKey`, `createdAt` |
| `syncOutboxMutations` | `mutationId`, `deviceId`, `actorAccountId?`, `robotId?`, `scopeState`, `idempotencyKey`, `entityType`, `operation`, `entityId`, `baseRevision?`, `payloadJson`, `state`, `attemptCount`, `nextAttemptAt?`, `lastAttemptAt?`, `lastErrorCode?`, `createdAt`, `updatedAt` |
| `carouselSlots` | `id`, `slotNumber`, `prescriptionId`, `scheduleId`, `profileId`, `status`, `createdAt`, `updatedAt` |
| `carouselLoadSessions` | `id`, `profileId`, `mode`, `status`, `predecessorSessionId?`, `planCreatedAt?`, `startedAt?`, `confirmedAt?`, `staleAt?`, `staleReason?`, `supersededAt?`, `supersededReason?`, `positionBefore`, `positionAfter`, `createdAt`, `updatedAt` |
| `carouselLoadSlotSnapshots` | `id`, `sessionId`, `slotNumber`, `status`, `scheduledAt?`, `bundleKey?`, `scheduleIdsJson`, `prescriptionIdsJson`, `prescriptionNamesJson`, `pillIconsJson`, `doseInstructionsJson`, `loadedAt?`, `movedAt?`, `resolvedAt?`, `reviewReason?`, `createdAt` |
| `carouselStates` | `profileId`, `activeLoadSessionId?`, `currentPosition`, `updatedAt` |
| `medicationShortageAlerts` | `id`, `profileId`, `loadSessionId?`, `slotNumber`, `bundleKey`, `scheduledAt`, `prescriptionIdsJson`, `prescriptionNamesJson`, `status`, `recognizedAt?`, `resolvedAt?`, `resolution?`, `intendedAudience`, `localDeliveryState`, `localNotificationSentAt?`, `remoteDeliveryState`, `createdAt`, `updatedAt` |
| `doseLogEvents` | `id`, `kind`, `doseId`, `occurredAt`, `marksDoseTaken` |
| `controllerCommandSessions` | `id`, `commandType`, `doseId?`, `scheduleId?`, `slotId?`, `state`, `failureReason?`, `createdAt`, `acceptedAt?`, `resolvedAt?`, `updatedAt` |
| `controllerCommandEvents` | `id`, `sessionId`, `sequence`, `eventType`, `occurredAt`, `details?` |
| `adminAuditEvents` | `id`, `eventType`, `targetType`, `targetId?`, `actorType`, `actorUserId?`, `actorLabel`, `sourceDeviceRole`, `summary`, `detailsJson?`, `cloudEventId?`, `lastSyncedAt?`, `occurredAt` |

`syncOutboxMutations` is portable local state. Pending, `in_flight`,
`succeeded`, and `permanent_failure` rows are restored exactly, including bound
account/robot IDs, retry timestamps/counts, and error fields. Restore does not
reset, rebind, requeue, or retry them. This does not make production sync
required or active: production mobile leaves sync default-off and unwired.

Only these setting keys are portable:

```text
household_display_name
profile_display_name
relationship_label
robot_face_voice_enabled
robot_face_voice_variety_enabled
robot_face_voice_volume_preset
robot_face_voice_quiet_hours_enabled
robot_face_voice_quiet_hours_start_minutes
robot_face_voice_quiet_hours_end_minutes
robot_face_voice_safety_during_quiet_hours_enabled
robot_face_reminder_voice_enabled
robot_face_dispense_narration_enabled
robot_face_safety_confirmation_voice_enabled
robot_face_missed_dose_voice_enabled
robot_face_controller_alert_voice_enabled
robot_face_idle_chatter_voice_enabled
robot_face_idle_chatter_cooldown_minutes
robot_face_reminder_repeat_cooldown_minutes
robot_face_reminder_repeat_policy
deferred_deleted_prescription:<prescription-id>
```

The final key requires a nonempty ID for a prescription in the document.
Authentication, Action PIN, device role, onboarding and safety acknowledgements,
robot identity, display and timing settings, and unknown settings are excluded
and preserved at the destination.

Pure derived projections, caches, and checkpoints are not separately backed up.
This includes reconciliation checkpoints and any remote-sync checkpoint: a
restore does not reinstate remote progress, reapply a checkpoint, or claim it
is current.

## Canonical encoding and validation

The encoder writes the envelope and section order above, sorts settings by
`key`, carousel states by `profileId`, outbox mutations by `mutationId`,
controller events by `sessionId`, `sequence`, then `id`, and other rows by
`id`. Row field names are sorted. Output has one trailing newline and no export
timestamp, so identical logical data has identical bytes.

Import is limited to 25 MiB and requires strict UTF-8 JSON, exact fields,
supported format/schema versions, valid types, enums, timestamps, unique IDs,
references, and embedded JSON. IDs and primary keys must be unique and nonempty.
Timestamps must be representable UTC whole seconds; `createdAt` must not follow
`updatedAt`, and lifecycle timestamps must not precede creation.

The validator also enforces these rules:

- Prescriptions use supported pill types/icons; counts are nonnegative except
  positive `defaultDoseCountPerDose`, and inventory satisfies:

```text
remainingDoses = availableDoses + loadedDoses + reviewDoses
```

- `usedDoses` is historical. Refill deltas are positive. Schedule hours are
  `0..23`, minutes are `0..59`, and schedule revisions are positive.
- Phone dose actions use a valid `YYYY-MM-DD` local date and one of
  `taken_confirmed`, `skipped`, `snoozed`, `help_requested`, `missed`, or
  `missed_acknowledged`. Only `taken_confirmed` marks Taken; terminal actions
  are unique per device occurrence, and Taken is unique per occurrence.
- Outbox rows use states `pending`, `in_flight`, `succeeded`, or
  `permanent_failure`. `local_only` rows have no account/robot IDs; `bound`
  rows require trimmed, nonempty account and robot IDs of at most 128 characters.
  Outbox idempotency keys are unique.
- Carousel slot numbers are `1..14`; carousel positions are `0..14`. There is
  exactly one active schedule profile and exactly one carousel state for each
  profile. Profile slot numbers and profile schedule assignments are unique;
  slots must match an enabled schedule in the same profile and prescription.
  Active and predecessor load sessions must belong to the same profile.
- Snapshot and shortage `*Json` values decode to arrays of strings. Snapshot
  parallel arrays have equal lengths; shortage prescription-ID and name arrays
  have equal lengths. `adminAuditEvents.detailsJson`, when present, decodes to
  an object. Controller `details` is plain nullable text.
- Controller-event sequences are positive, unique per session, and contiguous
  from one; every event references an existing command session. Referenced
  profiles, prescriptions, schedules, sessions, and carousel states must exist.
  A current shortage references a same-profile session.
- Dose-log `marksDoseTaken` is true only for confirmed, already-taken, early,
  or late Taken kinds. Controller movement, visibility, snooze, help, skipped,
  missed, missed recognition, and error events remain false.

## Restore

Before changing data, Dosey health-checks the current database, writes and
verifies the app-private `pre_restore_recovery.json`, then verifies the live
snapshot has not changed. It replaces included logical tables in one SQLite
transaction, canonically reads them back, and runs `PRAGMA integrity_check`
before commit. Any replacement or verification failure rolls back the database;
a recovery-write failure prevents replacement.

Restore writes exact persisted values. It never infers Taken, decrements
inventory, normalizes movement, or creates behavioral audit events. OS
notification instances are not exported; future reminders are reconciled only
after a successful commit. It does not restore remote checkpoints.
