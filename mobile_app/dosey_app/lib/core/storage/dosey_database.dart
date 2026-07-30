import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';

part 'dosey_database.g.dart';

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ReminderScheduleRow')
class ReminderSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get prescriptionId => text().nullable()();
  TextColumn get profileId =>
      text().withDefault(const Constant('schedule-1'))();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  BoolColumn get isEnabled => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (hour >= 0 AND hour <= 23)',
    'CHECK (minute >= 0 AND minute <= 59)',
    'CHECK (revision > 0)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ScheduleProfileRow')
class ScheduleProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PrescriptionRow')
class Prescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get pillType => text()();
  IntColumn get remainingDoses => integer().withDefault(const Constant(0))();
  TextColumn get guidedPillIcon =>
      text().withDefault(Constant(GuidedPillIcon.roundPill.storageValue))();
  IntColumn get availableDoses => integer().withDefault(const Constant(0))();
  IntColumn get loadedDoses => integer().withDefault(const Constant(0))();
  IntColumn get usedDoses => integer().withDefault(const Constant(0))();
  IntColumn get reviewDoses => integer().withDefault(const Constant(0))();
  IntColumn get defaultRefillQuantity =>
      integer().withDefault(const Constant(30))();
  IntColumn get defaultDoseCountPerDose =>
      integer().withDefault(const Constant(1))();
  TextColumn get doseInstructions => text().withDefault(const Constant(''))();
  IntColumn get refillThreshold => integer().withDefault(const Constant(3))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (remaining_doses >= 0)',
    'CHECK (available_doses >= 0)',
    'CHECK (loaded_doses >= 0)',
    'CHECK (used_doses >= 0)',
    'CHECK (review_doses >= 0)',
    'CHECK (default_refill_quantity >= 0)',
    'CHECK (default_dose_count_per_dose > 0)',
    'CHECK (refill_threshold >= 0)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PrescriptionRefillRow')
class PrescriptionRefills extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId => text()();
  IntColumn get doseDelta => integer()();
  IntColumn get remainingAfter => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  List<String> get customConstraints => const [
    'CHECK (dose_delta > 0)',
    'CHECK (remaining_after >= 0)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CarouselSlotRow')
class CarouselSlots extends Table {
  TextColumn get id => text()();
  IntColumn get slotNumber => integer()();
  TextColumn get prescriptionId => text()();
  TextColumn get scheduleId => text()();
  TextColumn get profileId => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (slot_number > 0)',
    "CHECK (status IN ('assigned', 'loaded', 'dispensed', 'needs_review'))",
    'UNIQUE (profile_id, slot_number)',
    'UNIQUE (profile_id, schedule_id)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CarouselLoadSessionRow')
class CarouselLoadSessions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get mode => text()();
  TextColumn get status => text()();
  TextColumn get predecessorSessionId => text().nullable()();
  DateTimeColumn get planCreatedAt => dateTime().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
  DateTimeColumn get staleAt => dateTime().nullable()();
  TextColumn get staleReason => text().nullable()();
  DateTimeColumn get supersededAt => dateTime().nullable()();
  TextColumn get supersededReason => text().nullable()();
  IntColumn get positionBefore => integer()();
  IntColumn get positionAfter => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    "CHECK (mode IN ('full_load', 'top_off'))",
    "CHECK (status IN ('draft', 'confirmed', 'stale', 'superseded', 'cancelled'))",
    'CHECK (position_before >= 0 AND position_before <= 14)',
    'CHECK (position_after >= 0 AND position_after <= 14)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CarouselLoadSlotSnapshotRow')
class CarouselLoadSlotSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get slotNumber => integer()();
  TextColumn get status => text()();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  TextColumn get bundleKey => text().nullable()();
  TextColumn get scheduleIdsJson => text()();
  TextColumn get prescriptionIdsJson => text()();
  TextColumn get prescriptionNamesJson => text()();
  TextColumn get pillIconsJson => text()();
  TextColumn get doseInstructionsJson => text()();
  DateTimeColumn get loadedAt => dateTime().nullable()();
  DateTimeColumn get movedAt => dateTime().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get reviewReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (slot_number >= 1 AND slot_number <= 14)',
    "CHECK (status IN ('loaded', 'retained', 'dispensed', 'needs_review', 'empty', 'shortage'))",
    'UNIQUE (session_id, slot_number)',
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CarouselStateRow')
class CarouselStates extends Table {
  TextColumn get profileId => text()();
  TextColumn get activeLoadSessionId => text().nullable()();
  IntColumn get currentPosition => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (current_position >= 0 AND current_position <= 14)',
  ];

  @override
  Set<Column> get primaryKey => {profileId};
}

@DataClassName('MedicationShortageAlertRow')
class MedicationShortageAlerts extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get loadSessionId => text().nullable()();
  IntColumn get slotNumber => integer()();
  TextColumn get bundleKey => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get prescriptionIdsJson => text()();
  TextColumn get prescriptionNamesJson => text()();
  TextColumn get status => text()();
  DateTimeColumn get recognizedAt => dateTime().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get resolution => text().nullable()();
  TextColumn get intendedAudience =>
      text().withDefault(const Constant('household'))();
  TextColumn get localDeliveryState => text()();
  DateTimeColumn get localNotificationSentAt => dateTime().nullable()();
  TextColumn get remoteDeliveryState =>
      text().withDefault(const Constant('not_configured'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (slot_number >= 1 AND slot_number <= 14)',
    "CHECK (status IN ('active', 'resolved', 'past_due'))",
    "CHECK (intended_audience IN ('household'))",
    "CHECK (local_delivery_state IN ('pending', 'sent', 'failed'))",
    "CHECK (remote_delivery_state IN ('not_configured'))",
  ];

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AuthSessionRow')
class AuthSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get provider => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DoseLogEventRow')
class DoseLogEvents extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get doseId => text()();
  DateTimeColumn get occurredAt => dateTime()();
  BoolColumn get marksDoseTaken => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PhoneDoseActionEventRow')
class PhoneDoseActionEvents extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  TextColumn get occurrenceId => text()();
  TextColumn get scheduleId => text()();
  IntColumn get scheduleRevision => integer()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get localDate => text()();
  TextColumn get timezoneId => text()();
  TextColumn get medicationId => text()();
  TextColumn get kind => text()();
  DateTimeColumn get occurredAt => dateTime()();
  BoolColumn get marksDoseTaken => boolean()();
  TextColumn get idempotencyKey => text().unique()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    "CHECK (kind IN ('taken_confirmed', 'skipped', 'snoozed', 'help_requested', 'missed', 'missed_acknowledged'))",
    "CHECK ((kind = 'taken_confirmed' AND marks_dose_taken = 1) OR (kind != 'taken_confirmed' AND marks_dose_taken = 0))",
  ];
}

@DataClassName('SyncOutboxMutationRow')
class SyncOutboxMutations extends Table {
  TextColumn get mutationId => text()();
  TextColumn get deviceId => text()();
  TextColumn get actorAccountId => text().nullable()();
  TextColumn get robotId => text().nullable()();
  TextColumn get scopeState =>
      text().withDefault(const Constant('local_only'))();
  TextColumn get idempotencyKey => text()();
  TextColumn get entityType => text()();
  TextColumn get operation => text()();
  TextColumn get entityId => text()();
  IntColumn get baseRevision => integer().nullable()();
  TextColumn get payloadJson => text()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {mutationId};

  @override
  List<String> get customConstraints => const [
    "CHECK (state IN ('pending', 'in_flight', 'succeeded', 'permanent_failure'))",
    'CHECK (attempt_count >= 0)',
    "CHECK ((scope_state = 'local_only' AND actor_account_id IS NULL AND robot_id IS NULL) OR (scope_state = 'bound' AND actor_account_id IS NOT NULL AND length(trim(actor_account_id)) BETWEEN 1 AND 128 AND robot_id IS NOT NULL AND length(trim(robot_id)) BETWEEN 1 AND 128))",
  ];
}

@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get scopeKey => text()();
  TextColumn get robotId => text().nullable()();
  TextColumn get cursor => text().nullable()();
  TextColumn get checkpoint => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {scopeKey};
}

@DataClassName('SyncConflictRow')
class SyncConflicts extends Table {
  TextColumn get mutationId => text()();
  TextColumn get outcome => text()();
  IntColumn get revision => integer().nullable()();
  TextColumn get cursor => text().nullable()();
  TextColumn get errorCode => text().nullable()();
  TextColumn get conflictJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {mutationId};
}

@DataClassName('MedicationSyncPullStateRow')
class MedicationSyncPullStates extends Table {
  TextColumn get accountId => text()();
  TextColumn get robotId => text()();
  TextColumn get cursor => text().nullable()();
  TextColumn get checkpoint => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, robotId};

  @override
  List<String> get customConstraints => const [
    'CHECK ((cursor IS NULL) = (checkpoint IS NULL))',
  ];
}

@DataClassName('SyncedMedicationRow')
class SyncedMedications extends Table {
  TextColumn get accountId => text()();
  TextColumn get robotId => text()();
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get pillType => text()();
  TextColumn get instructions => text().nullable()();
  IntColumn get revision => integer()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, robotId, id};

  @override
  List<String> get customConstraints => const ['CHECK (revision > 0)'];
}

@DataClassName('SyncedMedicationScheduleRow')
class SyncedMedicationSchedules extends Table {
  TextColumn get accountId => text()();
  TextColumn get robotId => text()();
  TextColumn get id => text()();
  TextColumn get medicationId => text()();
  TextColumn get label => text()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  TextColumn get timezoneId => text()();
  BoolColumn get isEnabled => boolean()();
  IntColumn get revision => integer()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, robotId, id};

  @override
  List<String> get customConstraints => const [
    'CHECK (hour >= 0 AND hour <= 23)',
    'CHECK (minute >= 0 AND minute <= 59)',
    'CHECK (revision > 0)',
  ];
}

@DataClassName('SyncedDoseEventRow')
class SyncedDoseEvents extends Table {
  TextColumn get accountId => text()();
  TextColumn get robotId => text()();
  TextColumn get id => text()();
  TextColumn get medicationId => text()();
  TextColumn get occurrenceId => text()();
  TextColumn get scheduleId => text()();
  IntColumn get scheduleRevision => integer()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get localDate => text()();
  TextColumn get timezoneId => text()();
  TextColumn get kind => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get actorAccountId => text()();

  @override
  Set<Column> get primaryKey => {accountId, robotId, id};

  @override
  List<String> get customConstraints => const [
    'CHECK (schedule_revision > 0)',
    "CHECK (kind IN ('taken_confirmed', 'skipped', 'snoozed', 'help_requested'))",
  ];
}

@DataClassName('ControllerCommandSessionRow')
class ControllerCommandSessions extends Table {
  TextColumn get id => text()();
  TextColumn get commandType => text()();
  TextColumn get doseId => text().nullable()();
  TextColumn get scheduleId => text().nullable()();
  TextColumn get slotId => text().nullable()();
  TextColumn get state => text()();
  TextColumn get failureReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get acceptedAt => dateTime().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'controller_command_sessions_unresolved_idx',
      'CREATE INDEX controller_command_sessions_unresolved_idx '
          'ON controller_command_sessions (resolved_at, state, updated_at)',
    ),
  ];
}

@DataClassName('ControllerCommandEventRow')
class ControllerCommandEvents extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get sequence => integer()();
  TextColumn get eventType => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get details => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'controller_command_events_session_sequence_idx',
      'CREATE UNIQUE INDEX controller_command_events_session_sequence_idx '
          'ON controller_command_events (session_id, sequence)',
    ),
  ];
}

@DataClassName('ControllerHealthEventRow')
@TableIndex.sql(
  'CREATE INDEX controller_health_events_occurred_at_idx '
  'ON controller_health_events (occurred_at DESC)',
)
class ControllerHealthEvents extends Table {
  TextColumn get id => text()();
  TextColumn get eventType => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get details => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AdminAuditEventRow')
class AdminAuditEvents extends Table {
  TextColumn get id => text()();
  TextColumn get eventType => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text().nullable()();
  TextColumn get actorType => text()();
  TextColumn get actorUserId => text().nullable()();
  TextColumn get actorLabel => text()();
  TextColumn get sourceDeviceRole => text()();
  TextColumn get summary => text()();
  TextColumn get detailsJson => text().nullable()();
  TextColumn get cloudEventId => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CachedRobotInstallationRow')
class CachedRobotInstallations extends Table {
  TextColumn get accountId => text()();
  TextColumn get robotId => text()();
  TextColumn get displayName => text()();
  TextColumn get ownerAccountId => text()();
  TextColumn get currentRole => text()();
  TextColumn get mountedDeviceId => text().nullable()();
  DateTimeColumn get confirmedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId};

  @override
  List<String> get customConstraints => const [
    "CHECK (current_role IN ('owner', 'member'))",
  ];
}

@DataClassName('CachedHouseholdMemberRow')
class CachedHouseholdMembers extends Table {
  TextColumn get accountId => text()();
  TextColumn get memberAccountId => text()();
  TextColumn get label => text()();
  TextColumn get role => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {accountId, memberAccountId};

  @override
  List<String> get customConstraints => const [
    "CHECK (role IN ('owner', 'member'))",
    'CHECK (position >= 0 AND position < 7)',
    'UNIQUE (account_id, position)',
  ];
}

@DriftDatabase(
  tables: [
    AppSettings,
    ReminderSchedules,
    Prescriptions,
    PrescriptionRefills,
    ScheduleProfiles,
    CarouselSlots,
    CarouselLoadSessions,
    CarouselLoadSlotSnapshots,
    CarouselStates,
    MedicationShortageAlerts,
    AuthSessions,
    DoseLogEvents,
    PhoneDoseActionEvents,
    SyncOutboxMutations,
    SyncCursors,
    SyncConflicts,
    MedicationSyncPullStates,
    SyncedMedications,
    SyncedMedicationSchedules,
    SyncedDoseEvents,
    ControllerCommandSessions,
    ControllerCommandEvents,
    ControllerHealthEvents,
    AdminAuditEvents,
    CachedRobotInstallations,
    CachedHouseholdMembers,
  ],
)
class DoseyDatabase extends _$DoseyDatabase {
  DoseyDatabase([QueryExecutor? executor, this.isDemo = false])
    : super(executor ?? _openConnection(name: 'dosey'));

  factory DoseyDatabase.demo() {
    return DoseyDatabase(_openConnection(name: 'dosey_demo'), true);
  }

  factory DoseyDatabase.inMemory({bool isDemo = false}) {
    return DoseyDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
      isDemo,
    );
  }

  final bool isDemo;

  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createPhoneDoseActionTerminalIndex();
      await _createOutboxIdempotencyIndexes();
      await _createScopedOutboxPendingIndex();
      await _createOutboxScopeImmutabilityTrigger();
      await _seedOnboardingCompleted(completed: false);
      await _seedDefaultScheduleProfile();
      await _seedCarouselStates();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(reminderSchedules);
      }
      if (from < 3) {
        await migrator.createTable(authSessions);
      }
      if (from >= 2 && from < 4) {
        await migrator.alterTable(TableMigration(reminderSchedules));
      }
      if (from < 5) {
        await _seedOnboardingCompleted(completed: true);
      }
      if (from < 6) {
        await migrator.createTable(prescriptions);
        if (from >= 2) {
          await migrator.addColumn(
            reminderSchedules,
            reminderSchedules.prescriptionId,
          );
        }
      }
      if (from < 7) {
        await migrator.createTable(scheduleProfiles);
        if (from >= 2) {
          await migrator.addColumn(
            reminderSchedules,
            reminderSchedules.profileId,
          );
        }
        await _seedDefaultScheduleProfile();
      }
      if (from < 8) {
        await migrator.createTable(carouselSlots);
      }
      if (from < 9) {
        await _createDoseLogEventsIfMissing();
      }
      if (from >= 8 && from < 9) {
        await _normalizeLegacyCarouselSlotStatuses();
        await migrator.alterTable(TableMigration(carouselSlots));
      }
      if (from < 10) {
        if (from >= 6) {
          await _rebuildLegacyPrescriptionsTableWithInventoryTracking();
        }
        await migrator.createTable(prescriptionRefills);
      }
      if (from < 11) {
        await migrator.createTable(controllerCommandSessions);
        await migrator.createTable(controllerCommandEvents);
      }
      if (from < 12) {
        await migrator.createTable(adminAuditEvents);
      }
      if (from < 13) {
        if (from >= 6) {
          await _rebuildPrescriptionsTableWithGuidedLoadingFields();
        }
        await migrator.createTable(carouselLoadSessions);
        await migrator.createTable(carouselLoadSlotSnapshots);
        await migrator.createTable(carouselStates);
        await migrator.createTable(medicationShortageAlerts);
        await _seedCarouselStates();
      }
      if (from >= 13 && from < 14) {
        await _rebuildCarouselLoadSlotSnapshotsTableWithRetainedStatus();
      }
      if (from < 15) {
        await migrator.createTable(controllerHealthEvents);
        await migrator.createIndex(controllerHealthEventsOccurredAtIdx);
      }
      if (from < 16) {
        await migrator.createTable(cachedRobotInstallations);
        await migrator.createTable(cachedHouseholdMembers);
      }
      if (from < 17) {
        await transaction(() async {
          if (from >= 2 && await _tableExists('reminder_schedules')) {
            await migrator.addColumn(
              reminderSchedules,
              reminderSchedules.revision,
            );
          }
          await migrator.createTable(phoneDoseActionEvents);
          await migrator.createTable(syncOutboxMutations);
          await migrator.createTable(syncCursors);
          await migrator.createTable(syncConflicts);
        });
      }
      if (from < 18) {
        await transaction(() async {
          await migrator.createTable(medicationSyncPullStates);
          await migrator.createTable(syncedMedications);
          await migrator.createTable(syncedMedicationSchedules);
          await migrator.createTable(syncedDoseEvents);
        });
      }
      if (from < 19) {
        await transaction(() async {
          if (from >= 17) {
            await _rebuildPhoneDoseActionEventsWithDeviceScope();
            await _rebuildSyncOutboxMutationsWithScope(migrator);
          } else {
            await _createPhoneDoseActionTerminalIndex();
          }
          await _createOutboxIdempotencyIndexes();
          await _createScopedOutboxPendingIndex();
          await _createOutboxScopeImmutabilityTrigger();
        });
      }
    },
  );

  Future<bool> _tableExists(String tableName) async {
    final row = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      variables: [Variable<String>(tableName)],
    ).getSingleOrNull();
    return row != null;
  }

  Future<void> _createOutboxScopeImmutabilityTrigger() {
    return customStatement('''
      CREATE TRIGGER IF NOT EXISTS sync_outbox_scope_immutable
      BEFORE UPDATE OF scope_state, actor_account_id, robot_id
      ON sync_outbox_mutations
      WHEN NEW.scope_state IS NOT OLD.scope_state
        OR NEW.actor_account_id IS NOT OLD.actor_account_id
        OR NEW.robot_id IS NOT OLD.robot_id
      BEGIN
        SELECT RAISE(ABORT, 'sync outbox scope is immutable');
      END;
    ''');
  }

  Future<void> _createPhoneDoseActionTerminalIndex() {
    return customStatement(
      "CREATE UNIQUE INDEX phone_dose_action_events_one_terminal ON phone_dose_action_events (device_id, occurrence_id) WHERE kind IN ('taken_confirmed', 'skipped', 'missed_acknowledged');",
    );
  }

  Future<void> _createScopedOutboxPendingIndex() {
    return customStatement(
      "CREATE INDEX sync_outbox_mutations_scoped_pending_idx ON sync_outbox_mutations (actor_account_id, robot_id, state, next_attempt_at, created_at, mutation_id) WHERE scope_state = 'bound' AND state = 'pending';",
    );
  }

  Future<void> _createOutboxIdempotencyIndexes() async {
    await customStatement(
      "CREATE UNIQUE INDEX sync_outbox_local_idempotency_idx ON sync_outbox_mutations (idempotency_key) WHERE scope_state = 'local_only';",
    );
    await customStatement(
      "CREATE UNIQUE INDEX sync_outbox_bound_robot_idempotency_idx ON sync_outbox_mutations (robot_id, idempotency_key) WHERE scope_state = 'bound';",
    );
  }

  Future<void> _rebuildSyncOutboxMutationsWithScope(Migrator migrator) async {
    await customStatement(
      'ALTER TABLE sync_outbox_mutations RENAME TO sync_outbox_mutations_old;',
    );
    await migrator.createTable(syncOutboxMutations);
    await customStatement('''
      INSERT INTO sync_outbox_mutations (
        mutation_id, device_id, actor_account_id, robot_id, scope_state,
        idempotency_key, entity_type, operation, entity_id, base_revision,
        payload_json, state, attempt_count, next_attempt_at, last_attempt_at,
        last_error_code, created_at, updated_at
      )
      SELECT
        mutation_id, device_id, NULL, NULL, 'local_only', idempotency_key,
        entity_type, operation, entity_id, base_revision, payload_json, state,
        attempt_count, next_attempt_at, last_attempt_at, last_error_code,
        created_at, updated_at
      FROM sync_outbox_mutations_old;
    ''');
    await customStatement('DROP TABLE sync_outbox_mutations_old;');
  }

  Future<void> _rebuildPhoneDoseActionEventsWithDeviceScope() async {
    await customStatement(
      'ALTER TABLE phone_dose_action_events RENAME TO phone_dose_action_events_old;',
    );
    await customStatement('''
      CREATE TABLE phone_dose_action_events (
        id TEXT NOT NULL PRIMARY KEY,
        device_id TEXT NOT NULL,
        occurrence_id TEXT NOT NULL,
        schedule_id TEXT NOT NULL,
        schedule_revision INTEGER NOT NULL,
        scheduled_at INTEGER NOT NULL,
        local_date TEXT NOT NULL,
        timezone_id TEXT NOT NULL,
        medication_id TEXT NOT NULL,
        kind TEXT NOT NULL CHECK (kind IN ('taken_confirmed', 'skipped', 'snoozed', 'help_requested', 'missed', 'missed_acknowledged')),
        occurred_at INTEGER NOT NULL,
        marks_dose_taken INTEGER NOT NULL CHECK ((kind = 'taken_confirmed' AND marks_dose_taken = 1) OR (kind != 'taken_confirmed' AND marks_dose_taken = 0)),
        idempotency_key TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      );
    ''');
    await customStatement('''
      INSERT INTO phone_dose_action_events (
        id, device_id, occurrence_id, schedule_id, schedule_revision,
        scheduled_at, local_date, timezone_id, medication_id, kind,
        occurred_at, marks_dose_taken, idempotency_key, created_at
      )
      SELECT
        id, 'legacy-unknown-device', occurrence_id, schedule_id,
        schedule_revision, scheduled_at, local_date, timezone_id,
        medication_id, kind, occurred_at, marks_dose_taken,
        idempotency_key, created_at
      FROM phone_dose_action_events_old;
    ''');
    await customStatement('DROP TABLE phone_dose_action_events_old;');
    await customStatement(
      "CREATE UNIQUE INDEX phone_dose_action_events_one_terminal ON phone_dose_action_events (device_id, occurrence_id) WHERE kind IN ('taken_confirmed', 'skipped', 'missed_acknowledged');",
    );
  }

  Future<void>
  _rebuildCarouselLoadSlotSnapshotsTableWithRetainedStatus() async {
    await transaction(() async {
      await customStatement(
        'ALTER TABLE carousel_load_slot_snapshots RENAME TO carousel_load_slot_snapshots_old;',
      );
      await customStatement('''
        CREATE TABLE carousel_load_slot_snapshots (
          id TEXT NOT NULL PRIMARY KEY,
          session_id TEXT NOT NULL,
          slot_number INTEGER NOT NULL CHECK (slot_number >= 1 AND slot_number <= 14),
          status TEXT NOT NULL CHECK (status IN ('loaded', 'retained', 'dispensed', 'needs_review', 'empty', 'shortage')),
          scheduled_at INTEGER NULL,
          bundle_key TEXT NULL,
          schedule_ids_json TEXT NOT NULL,
          prescription_ids_json TEXT NOT NULL,
          prescription_names_json TEXT NOT NULL,
          pill_icons_json TEXT NOT NULL,
          dose_instructions_json TEXT NOT NULL,
          loaded_at INTEGER NULL,
          moved_at INTEGER NULL,
          resolved_at INTEGER NULL,
          review_reason TEXT NULL,
          created_at INTEGER NOT NULL,
          UNIQUE (session_id, slot_number)
        );
      ''');
      await customStatement('''
        INSERT INTO carousel_load_slot_snapshots (
          id,
          session_id,
          slot_number,
          status,
          scheduled_at,
          bundle_key,
          schedule_ids_json,
          prescription_ids_json,
          prescription_names_json,
          pill_icons_json,
          dose_instructions_json,
          loaded_at,
          moved_at,
          resolved_at,
          review_reason,
          created_at
        )
        SELECT
          id,
          session_id,
          slot_number,
          status,
          scheduled_at,
          bundle_key,
          schedule_ids_json,
          prescription_ids_json,
          prescription_names_json,
          pill_icons_json,
          dose_instructions_json,
          loaded_at,
          moved_at,
          resolved_at,
          review_reason,
          created_at
        FROM carousel_load_slot_snapshots_old;
      ''');
      await customStatement('DROP TABLE carousel_load_slot_snapshots_old;');
    });
  }

  Future<void> _createDoseLogEventsIfMissing() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS dose_log_events (
        id TEXT NOT NULL PRIMARY KEY,
        kind TEXT NOT NULL,
        dose_id TEXT NOT NULL,
        occurred_at INTEGER NOT NULL,
        marks_dose_taken INTEGER NOT NULL CHECK (marks_dose_taken IN (0, 1))
      );
    ''');
  }

  Future<void> _normalizeLegacyCarouselSlotStatuses() {
    return customStatement('''
      UPDATE carousel_slots
      SET status = 'needs_review'
      WHERE status NOT IN ('assigned', 'loaded', 'dispensed', 'needs_review');
    ''');
  }

  Future<void> _rebuildLegacyPrescriptionsTableWithInventoryTracking() async {
    await transaction(() async {
      await customStatement(
        'ALTER TABLE prescriptions RENAME TO prescriptions_old;',
      );
      await customStatement('''
        CREATE TABLE prescriptions (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          pill_type TEXT NOT NULL,
          remaining_doses INTEGER NOT NULL DEFAULT 0 CHECK (remaining_doses >= 0),
          refill_threshold INTEGER NOT NULL DEFAULT 3 CHECK (refill_threshold >= 0),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      await customStatement('''
        INSERT INTO prescriptions (
          id,
          name,
          pill_type,
          remaining_doses,
          refill_threshold,
          created_at,
          updated_at
        )
        SELECT
          id,
          name,
          pill_type,
          0,
          3,
          created_at,
          updated_at
        FROM prescriptions_old;
      ''');
      await customStatement('DROP TABLE prescriptions_old;');
    });
  }

  Future<void> _rebuildPrescriptionsTableWithGuidedLoadingFields() async {
    await transaction(() async {
      await customStatement(
        'ALTER TABLE prescriptions RENAME TO prescriptions_old;',
      );
      await customStatement('''
        CREATE TABLE prescriptions (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          pill_type TEXT NOT NULL,
          remaining_doses INTEGER NOT NULL DEFAULT 0 CHECK (remaining_doses >= 0),
          guided_pill_icon TEXT NOT NULL DEFAULT '${GuidedPillIcon.roundPill.storageValue}',
          available_doses INTEGER NOT NULL DEFAULT 0 CHECK (available_doses >= 0),
          loaded_doses INTEGER NOT NULL DEFAULT 0 CHECK (loaded_doses >= 0),
          used_doses INTEGER NOT NULL DEFAULT 0 CHECK (used_doses >= 0),
          review_doses INTEGER NOT NULL DEFAULT 0 CHECK (review_doses >= 0),
          default_refill_quantity INTEGER NOT NULL DEFAULT 30 CHECK (default_refill_quantity >= 0),
          default_dose_count_per_dose INTEGER NOT NULL DEFAULT 1 CHECK (default_dose_count_per_dose > 0),
          dose_instructions TEXT NOT NULL DEFAULT '',
          refill_threshold INTEGER NOT NULL DEFAULT 3 CHECK (refill_threshold >= 0),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');
      await customStatement('''
        INSERT INTO prescriptions (
          id,
          name,
          pill_type,
          remaining_doses,
          guided_pill_icon,
          available_doses,
          loaded_doses,
          used_doses,
          review_doses,
          default_refill_quantity,
          default_dose_count_per_dose,
          dose_instructions,
          refill_threshold,
          created_at,
          updated_at
        )
        SELECT
          id,
          name,
          pill_type,
          remaining_doses,
          '${GuidedPillIcon.roundPill.storageValue}',
          remaining_doses,
          0,
          0,
          0,
          30,
          1,
          '',
          refill_threshold,
          created_at,
          updated_at
        FROM prescriptions_old;
      ''');
      await customStatement('DROP TABLE prescriptions_old;');
    });
  }

  Future<void> _seedOnboardingCompleted({required bool completed}) async {
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        key: 'onboarding_completed',
        value: completed.toString(),
        updatedAt: DateTime.now().toUtc(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> _seedDefaultScheduleProfile() async {
    final now = DateTime.now().toUtc();
    await into(scheduleProfiles).insert(
      ScheduleProfilesCompanion.insert(
        id: 'schedule-1',
        name: 'Schedule 1',
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> _seedCarouselStates() async {
    final now = DateTime.now().toUtc();
    final profiles = await select(scheduleProfiles).get();
    await batch((batch) {
      for (final profile in profiles) {
        batch.insert(
          carouselStates,
          CarouselStatesCompanion.insert(profileId: profile.id, updatedAt: now),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Stream<List<AppSetting>> watchAppSettings(Set<String> keys) {
    final query = select(appSettings)
      ..where((setting) => setting.key.isIn(keys));
    return query.watch();
  }

  Future<List<AppSetting>> getAppSettings(Set<String> keys) {
    final query = select(appSettings)
      ..where((setting) => setting.key.isIn(keys));
    return query.get();
  }

  Future<void> setAppSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: key,
        value: value,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> deleteAppSettings(Set<String> keys) {
    return (delete(
      appSettings,
    )..where((setting) => setting.key.isIn(keys))).go();
  }
}

QueryExecutor _openConnection({required String name}) {
  return driftDatabase(name: name);
}
