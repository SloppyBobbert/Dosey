# Dosey Local Backup Format

Dosey local backups are logical, versioned JSON documents. They are not copies
of the SQLite database, WAL, or shared-memory files.

## Sensitive Data Warning

Version 1 backups are plain UTF-8 JSON and are not encrypted. They can contain
medication names, schedules, dose history, household labels, and audit actor
details. Anyone who can read the exported file can read that information.

Plain JSON keeps this prototype portable and recoverable across supported
devices. Password encryption would require a cryptographic envelope, key
derivation, password and recovery UX, and password-loss handling. Device-key
encryption would prevent normal cross-device restore. A later format version
can add an encrypted envelope without changing version 1 files.

## Envelope

Every version 1 document has exactly these top-level fields:

```json
{
  "format": "dosey-local-backup",
  "formatVersion": 1,
  "sourceSchemaVersion": 14,
  "data": {}
}
```

Version 1 accepts only source schema version 14. `data` has exactly these array
fields, in this canonical order:

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

`authSessions` is intentionally absent.

## Versioning And Database Schema

The Drift database schema version and portable backup `sourceSchemaVersion` are
independent contracts. Backup format version 1 began at database schema 14.
Database migrations 15 and 16 add device-local tables that are excluded from
portable backups, so version 1 backups with source schema 14 remain valid.

Change the backup version or supported `sourceSchemaVersion` only when the
portable backup contract changes. A database-only migration does not require a
new portable backup version.

## Fields

Each row must contain exactly the listed fields. A `?` suffix means the value
may be JSON `null`; all other fields are required. Timestamps are UTC integer
microseconds since the Unix epoch and must represent whole seconds.

| Section | Fields |
| --- | --- |
| `settings` | `key`, `value`, `updatedAt` |
| `scheduleProfiles` | `id`, `name`, `isActive`, `createdAt`, `updatedAt` |
| `prescriptions` | `id`, `name`, `pillType`, `remainingDoses`, `guidedPillIcon`, `availableDoses`, `loadedDoses`, `usedDoses`, `reviewDoses`, `defaultRefillQuantity`, `defaultDoseCountPerDose`, `doseInstructions`, `refillThreshold`, `createdAt`, `updatedAt` |
| `prescriptionRefills` | `id`, `prescriptionId`, `doseDelta`, `remainingAfter`, `occurredAt`, `note?` |
| `reminderSchedules` | `id`, `label`, `prescriptionId?`, `profileId`, `hour`, `minute`, `isEnabled`, `createdAt`, `updatedAt` |
| `carouselSlots` | `id`, `slotNumber`, `prescriptionId`, `scheduleId`, `profileId`, `status`, `createdAt`, `updatedAt` |
| `carouselLoadSessions` | `id`, `profileId`, `mode`, `status`, `predecessorSessionId?`, `planCreatedAt?`, `startedAt?`, `confirmedAt?`, `staleAt?`, `staleReason?`, `supersededAt?`, `supersededReason?`, `positionBefore`, `positionAfter`, `createdAt`, `updatedAt` |
| `carouselLoadSlotSnapshots` | `id`, `sessionId`, `slotNumber`, `status`, `scheduledAt?`, `bundleKey?`, `scheduleIdsJson`, `prescriptionIdsJson`, `prescriptionNamesJson`, `pillIconsJson`, `doseInstructionsJson`, `loadedAt?`, `movedAt?`, `resolvedAt?`, `reviewReason?`, `createdAt` |
| `carouselStates` | `profileId`, `activeLoadSessionId?`, `currentPosition`, `updatedAt` |
| `medicationShortageAlerts` | `id`, `profileId`, `loadSessionId?`, `slotNumber`, `bundleKey`, `scheduledAt`, `prescriptionIdsJson`, `prescriptionNamesJson`, `status`, `recognizedAt?`, `resolvedAt?`, `resolution?`, `intendedAudience`, `localDeliveryState`, `localNotificationSentAt?`, `remoteDeliveryState`, `createdAt`, `updatedAt` |
| `doseLogEvents` | `id`, `kind`, `doseId`, `occurredAt`, `marksDoseTaken` |
| `controllerCommandSessions` | `id`, `commandType`, `doseId?`, `scheduleId?`, `slotId?`, `state`, `failureReason?`, `createdAt`, `acceptedAt?`, `resolvedAt?`, `updatedAt` |
| `controllerCommandEvents` | `id`, `sessionId`, `sequence`, `eventType`, `occurredAt`, `details?` |
| `adminAuditEvents` | `id`, `eventType`, `targetType`, `targetId?`, `actorType`, `actorUserId?`, `actorLabel`, `sourceDeviceRole`, `summary`, `detailsJson?`, `cloudEventId?`, `lastSyncedAt?`, `occurredAt` |

Fields ending in `Json` remain JSON-encoded strings in the outer document.
Snapshot and shortage list fields must decode to arrays of strings; snapshot
parallel arrays must have equal lengths. `adminAuditEvents.detailsJson`, when
present, must decode to an object. Controller `details` is ordinary text.

## Settings Policy

Only these portable settings are included:

- `household_display_name`
- `profile_display_name`
- `relationship_label`
- `robot_face_voice_enabled`
- `robot_face_voice_variety_enabled`
- `robot_face_voice_volume_preset`
- `robot_face_voice_quiet_hours_enabled`
- `robot_face_voice_quiet_hours_start_minutes`
- `robot_face_voice_quiet_hours_end_minutes`
- `robot_face_voice_safety_during_quiet_hours_enabled`
- `robot_face_reminder_voice_enabled`
- `robot_face_dispense_narration_enabled`
- `robot_face_safety_confirmation_voice_enabled`
- `robot_face_missed_dose_voice_enabled`
- `robot_face_controller_alert_voice_enabled`
- `robot_face_idle_chatter_voice_enabled`
- `robot_face_idle_chatter_cooldown_minutes`
- `robot_face_reminder_repeat_cooldown_minutes`
- `robot_face_reminder_repeat_policy`
- `deferred_deleted_prescription:<prescription-id>` for nonempty IDs

Restore preserves destination authentication rows and all excluded settings,
including Action PIN hash/salt, device role, onboarding and safety
acknowledgement, robot-hub identity, face orientation, screen/display timing,
wake timing, inactivity timing, and unknown keys. This prevents an Android
Robot Mode role from being imported onto iOS.

## Canonical Encoding

The encoder uses the envelope and section order above. Settings sort by `key`,
carousel states by `profileId`, controller events by `sessionId`, `sequence`,
then `id`, and other rows by `id`. Output ends with one newline and contains no
export timestamp, so identical logical data produces identical bytes.

## Validation And Restore

Import is limited to 25 MiB and requires strict UTF-8, valid JSON, exact fields
and primitive types, supported versions, valid enums and timestamps, unique
IDs and composite positions, valid required references, and valid embedded
JSON. Carousel positions are limited to `0..14`; slot positions use `1..14`.
There must be exactly one active schedule profile and one carousel state per
profile. Controller event sequences are contiguous from one.

Inventory must satisfy:

```text
remainingDoses = availableDoses + loadedDoses + reviewDoses
```

`usedDoses` is historical and is not part of that equation. Only confirmed,
already-taken, early, and late dose kinds may set `marksDoseTaken` to `true`.
Controller movement, visible confirmation, snooze, help, skipped, missed,
missed recognition, and error events must remain false.

Before replacement, Dosey checks the current database, writes and verifies one
app-private `pre_restore_recovery.json`, then replaces the included logical
tables in one SQLite transaction. It performs canonical read-back validation
and `PRAGMA integrity_check` before commit. Any failure rolls back the database;
a recovery-write failure prevents deletion. Restore inserts exact persisted
values and never infers a taken dose, decrements inventory, normalizes movement,
or creates behavioral audit events.

Persisted shortage delivery fields are historical and remain exact. OS
notification instances are not exported; future reminder scheduling is
reconciled only after a successful commit.
