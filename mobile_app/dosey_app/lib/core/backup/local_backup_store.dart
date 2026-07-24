import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

import 'backup_document.dart';
import 'backup_validator.dart';

enum DatabaseHealthStatus {
  healthy,
  physicalFailure,
  logicalFailure,
  unreadable,
}

class DatabaseHealthResult {
  const DatabaseHealthResult(this.status, {this.diagnostic});

  final DatabaseHealthStatus status;
  final String? diagnostic;

  bool get healthy => status == DatabaseHealthStatus.healthy;
}

class LocalBackupStore {
  LocalBackupStore(this.database, {this.validator = const BackupValidator()});

  final DoseyDatabase database;
  final BackupValidator validator;

  Future<BackupDocument> readSnapshot() async {
    final data = BackupDocument.emptyData();
    for (final config in _configs) {
      final result = await database
          .customSelect('SELECT * FROM ${config.table}')
          .get();
      data[config.section] = [
        for (final queryRow in result)
          {
            for (final field in config.fields.entries)
              field.key: _readValue(
                queryRow.data[field.value],
                timestamp: config.timestamps.contains(field.key),
                boolean: config.booleans.contains(field.key),
              ),
          },
      ];
    }
    data['settings'] = data['settings']!
        .where((row) => isPortableSettingKey(row['key']! as String))
        .toList();
    return BackupDocument(data: data);
  }

  Future<void> replaceSnapshot(BackupDocument snapshot) async {
    validator.validateOrThrow(snapshot);
    await database.batch((batch) {
      for (final config in _configs.reversed) {
        final updates = [TableUpdate(config.table)];
        if (config.section == 'settings') {
          final placeholders = List.filled(
            portableSettingKeys.length,
            '?',
          ).join(',');
          batch.customStatement(
            "DELETE FROM app_settings WHERE key IN ($placeholders) OR key GLOB ?",
            [...portableSettingKeys, '$deferredDeletedPrescriptionPrefix*'],
            updates,
          );
        } else {
          batch.customStatement('DELETE FROM ${config.table}', null, updates);
        }
      }

      for (final config in _configs) {
        final updates = [TableUpdate(config.table)];
        final fields = config.fields.keys.toList();
        final columns = fields.map((field) => config.fields[field]).join(',');
        final placeholders = List.filled(fields.length, '?').join(',');
        for (final row in snapshot.data[config.section]!) {
          batch.customStatement(
            'INSERT INTO ${config.table} ($columns) VALUES ($placeholders)',
            [
              for (final field in fields)
                _writeValue(
                  row[field],
                  timestamp: config.timestamps.contains(field),
                ),
            ],
            updates,
          );
        }
      }
    });
  }

  Future<bool> integrityIsOk() async {
    final rows = await database.customSelect('PRAGMA integrity_check').get();
    return rows.length == 1 && rows.single.data.values.single == 'ok';
  }

  Future<DatabaseHealthResult> checkHealth() async {
    try {
      if (!await integrityIsOk()) {
        return const DatabaseHealthResult(DatabaseHealthStatus.physicalFailure);
      }
      final issues = validator.validate(await readSnapshot());
      if (issues.isNotEmpty) {
        return DatabaseHealthResult(
          DatabaseHealthStatus.logicalFailure,
          diagnostic: issues.first.path,
        );
      }
      return const DatabaseHealthResult(DatabaseHealthStatus.healthy);
    } on Object {
      return const DatabaseHealthResult(DatabaseHealthStatus.unreadable);
    }
  }

  static Object? _readValue(
    Object? value, {
    required bool timestamp,
    required bool boolean,
  }) {
    if (value == null) return null;
    if (timestamp && value is int) {
      return value * Duration.microsecondsPerSecond;
    }
    if (boolean && value is int) return value != 0;
    return value;
  }

  static Object? _writeValue(Object? value, {required bool timestamp}) {
    if (value == null) return null;
    if (timestamp) return (value as int) ~/ Duration.microsecondsPerSecond;
    if (value is String || value is int || value is bool) return value;
    throw ArgumentError('Unsupported backup field type.');
  }
}

class _TableConfig {
  const _TableConfig(
    this.section,
    this.table,
    this.fields, {
    this.timestamps = const {},
    this.booleans = const {},
  });

  final String section;
  final String table;
  final Map<String, String> fields;
  final Set<String> timestamps;
  final Set<String> booleans;
}

const _configs = <_TableConfig>[
  _TableConfig(
    'settings',
    'app_settings',
    {'key': 'key', 'value': 'value', 'updatedAt': 'updated_at'},
    timestamps: {'updatedAt'},
  ),
  _TableConfig(
    'scheduleProfiles',
    'schedule_profiles',
    {
      'id': 'id',
      'name': 'name',
      'isActive': 'is_active',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
    },
    timestamps: {'createdAt', 'updatedAt'},
    booleans: {'isActive'},
  ),
  _TableConfig(
    'prescriptions',
    'prescriptions',
    {
      'id': 'id',
      'name': 'name',
      'pillType': 'pill_type',
      'remainingDoses': 'remaining_doses',
      'guidedPillIcon': 'guided_pill_icon',
      'availableDoses': 'available_doses',
      'loadedDoses': 'loaded_doses',
      'usedDoses': 'used_doses',
      'reviewDoses': 'review_doses',
      'defaultRefillQuantity': 'default_refill_quantity',
      'defaultDoseCountPerDose': 'default_dose_count_per_dose',
      'doseInstructions': 'dose_instructions',
      'refillThreshold': 'refill_threshold',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
    },
    timestamps: {'createdAt', 'updatedAt'},
  ),
  _TableConfig(
    'prescriptionRefills',
    'prescription_refills',
    {
      'id': 'id',
      'prescriptionId': 'prescription_id',
      'doseDelta': 'dose_delta',
      'remainingAfter': 'remaining_after',
      'occurredAt': 'occurred_at',
      'note': 'note',
    },
    timestamps: {'occurredAt'},
  ),
  _TableConfig(
    'reminderSchedules',
    'reminder_schedules',
    {
      'id': 'id',
      'label': 'label',
      'prescriptionId': 'prescription_id',
      'profileId': 'profile_id',
      'hour': 'hour',
      'minute': 'minute',
      'isEnabled': 'is_enabled',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
    },
    timestamps: {'createdAt', 'updatedAt'},
    booleans: {'isEnabled'},
  ),
  _TableConfig(
    'carouselSlots',
    'carousel_slots',
    {
      'id': 'id',
      'slotNumber': 'slot_number',
      'prescriptionId': 'prescription_id',
      'scheduleId': 'schedule_id',
      'profileId': 'profile_id',
      'status': 'status',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
    },
    timestamps: {'createdAt', 'updatedAt'},
  ),
  _TableConfig(
    'carouselLoadSessions',
    'carousel_load_sessions',
    {
      'id': 'id',
      'profileId': 'profile_id',
      'mode': 'mode',
      'status': 'status',
      'predecessorSessionId': 'predecessor_session_id',
      'planCreatedAt': 'plan_created_at',
      'startedAt': 'started_at',
      'confirmedAt': 'confirmed_at',
      'staleAt': 'stale_at',
      'staleReason': 'stale_reason',
      'supersededAt': 'superseded_at',
      'supersededReason': 'superseded_reason',
      'positionBefore': 'position_before',
      'positionAfter': 'position_after',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
    },
    timestamps: {
      'planCreatedAt',
      'startedAt',
      'confirmedAt',
      'staleAt',
      'supersededAt',
      'createdAt',
      'updatedAt',
    },
  ),
  _TableConfig(
    'carouselLoadSlotSnapshots',
    'carousel_load_slot_snapshots',
    {
      'id': 'id',
      'sessionId': 'session_id',
      'slotNumber': 'slot_number',
      'status': 'status',
      'scheduledAt': 'scheduled_at',
      'bundleKey': 'bundle_key',
      'scheduleIdsJson': 'schedule_ids_json',
      'prescriptionIdsJson': 'prescription_ids_json',
      'prescriptionNamesJson': 'prescription_names_json',
      'pillIconsJson': 'pill_icons_json',
      'doseInstructionsJson': 'dose_instructions_json',
      'loadedAt': 'loaded_at',
      'movedAt': 'moved_at',
      'resolvedAt': 'resolved_at',
      'reviewReason': 'review_reason',
      'createdAt': 'created_at',
    },
    timestamps: {
      'scheduledAt',
      'loadedAt',
      'movedAt',
      'resolvedAt',
      'createdAt',
    },
  ),
  _TableConfig(
    'carouselStates',
    'carousel_states',
    {
      'profileId': 'profile_id',
      'activeLoadSessionId': 'active_load_session_id',
      'currentPosition': 'current_position',
      'updatedAt': 'updated_at',
    },
    timestamps: {'updatedAt'},
  ),
  _TableConfig(
    'medicationShortageAlerts',
    'medication_shortage_alerts',
    {
      'id': 'id',
      'profileId': 'profile_id',
      'loadSessionId': 'load_session_id',
      'slotNumber': 'slot_number',
      'bundleKey': 'bundle_key',
      'scheduledAt': 'scheduled_at',
      'prescriptionIdsJson': 'prescription_ids_json',
      'prescriptionNamesJson': 'prescription_names_json',
      'status': 'status',
      'recognizedAt': 'recognized_at',
      'resolvedAt': 'resolved_at',
      'resolution': 'resolution',
      'intendedAudience': 'intended_audience',
      'localDeliveryState': 'local_delivery_state',
      'localNotificationSentAt': 'local_notification_sent_at',
      'remoteDeliveryState': 'remote_delivery_state',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
    },
    timestamps: {
      'scheduledAt',
      'recognizedAt',
      'resolvedAt',
      'localNotificationSentAt',
      'createdAt',
      'updatedAt',
    },
  ),
  _TableConfig(
    'doseLogEvents',
    'dose_log_events',
    {
      'id': 'id',
      'kind': 'kind',
      'doseId': 'dose_id',
      'occurredAt': 'occurred_at',
      'marksDoseTaken': 'marks_dose_taken',
    },
    timestamps: {'occurredAt'},
    booleans: {'marksDoseTaken'},
  ),
  _TableConfig(
    'controllerCommandSessions',
    'controller_command_sessions',
    {
      'id': 'id',
      'commandType': 'command_type',
      'doseId': 'dose_id',
      'scheduleId': 'schedule_id',
      'slotId': 'slot_id',
      'state': 'state',
      'failureReason': 'failure_reason',
      'createdAt': 'created_at',
      'acceptedAt': 'accepted_at',
      'resolvedAt': 'resolved_at',
      'updatedAt': 'updated_at',
    },
    timestamps: {'createdAt', 'acceptedAt', 'resolvedAt', 'updatedAt'},
  ),
  _TableConfig(
    'controllerCommandEvents',
    'controller_command_events',
    {
      'id': 'id',
      'sessionId': 'session_id',
      'sequence': 'sequence',
      'eventType': 'event_type',
      'occurredAt': 'occurred_at',
      'details': 'details',
    },
    timestamps: {'occurredAt'},
  ),
  _TableConfig(
    'adminAuditEvents',
    'admin_audit_events',
    {
      'id': 'id',
      'eventType': 'event_type',
      'targetType': 'target_type',
      'targetId': 'target_id',
      'actorType': 'actor_type',
      'actorUserId': 'actor_user_id',
      'actorLabel': 'actor_label',
      'sourceDeviceRole': 'source_device_role',
      'summary': 'summary',
      'detailsJson': 'details_json',
      'cloudEventId': 'cloud_event_id',
      'lastSyncedAt': 'last_synced_at',
      'occurredAt': 'occurred_at',
    },
    timestamps: {'lastSyncedAt', 'occurredAt'},
  ),
];
