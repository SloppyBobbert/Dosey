import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/domain_contracts.dart';
import 'package:dosey_app/core/sync/medication_sync_pull_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DoseyDatabase database;
  late DriftMedicationSyncPullRepository repository;
  const scope = AuthorizedCachedSyncScope(
    accountId: 'account-1',
    robotId: 'robot-1',
  );

  setUp(() async {
    database = DoseyDatabase.inMemory();
    repository = DriftMedicationSyncPullRepository(database);
    await _seedAuthorizedScope(database, scope);
  });

  tearDown(() => database.close());

  test(
    'applies a page and cursor atomically without operational effects',
    () async {
      final page = _page(
        nextCursor: '3',
        checkpoint: '3',
        changes: [
          _change('1', _medication(revision: 1)),
          _change('2', _schedule(revision: 1)),
          _change('3', _doseEvent()),
        ],
      );

      await repository.applyPage(scope: scope, page: page);

      final medications = await database
          .select(database.syncedMedications)
          .get();
      final schedules = await database
          .select(database.syncedMedicationSchedules)
          .get();
      final events = await database.select(database.syncedDoseEvents).get();
      final pullState = await database
          .select(database.medicationSyncPullStates)
          .getSingle();
      expect(medications.single.name, 'Aspirin');
      expect(schedules.single.timezoneId, 'UTC');
      expect(events.single.actorAccountId, 'caregiver-1');
      expect(pullState.cursor, '3');
      expect(pullState.checkpoint, '3');
      expect(await database.select(database.prescriptions).get(), isEmpty);
      expect(await database.select(database.reminderSchedules).get(), isEmpty);
      expect(await database.select(database.doseLogEvents).get(), isEmpty);
      expect(
        await database.select(database.phoneDoseActionEvents).get(),
        isEmpty,
      );
      expect(await database.select(database.carouselSlots).get(), isEmpty);
    },
  );

  test('equal revision mismatch rolls back records and cursor', () async {
    await repository.applyPage(
      scope: scope,
      page: _page(
        nextCursor: '1',
        checkpoint: '3',
        changes: [_change('1', _medication(revision: 1))],
      ),
    );

    await expectLater(
      repository.applyPage(
        scope: scope,
        page: _page(
          cursor: '1',
          nextCursor: '3',
          checkpoint: '3',
          changes: [
            _change('2', _schedule(revision: 1)),
            _change(
              '3',
              _medication(revision: 1, name: 'Changed at same revision'),
            ),
          ],
        ),
      ),
      throwsStateError,
    );

    expect(
      await database.select(database.syncedMedicationSchedules).get(),
      isEmpty,
    );
    expect(
      (await database.select(database.syncedMedications).getSingle()).name,
      'Aspirin',
    );
    expect(
      (await database.select(database.medicationSyncPullStates).getSingle())
          .cursor,
      '1',
    );
  });

  test(
    'rejects a page when cached account and robot binding is absent',
    () async {
      await database.delete(database.cachedHouseholdMembers).go();

      await expectLater(
        repository.applyPage(
          scope: scope,
          page: _page(
            nextCursor: '1',
            checkpoint: '1',
            changes: [_change('1', _medication(revision: 1))],
          ),
        ),
        throwsStateError,
      );

      expect(await database.select(database.syncedMedications).get(), isEmpty);
      expect(
        await database.select(database.medicationSyncPullStates).get(),
        isEmpty,
      );
    },
  );

  test(
    'higher revisions replace tombstones while older pages cannot overwrite',
    () async {
      await repository.applyPage(
        scope: scope,
        page: _page(
          nextCursor: '1',
          checkpoint: '3',
          changes: [_change('1', _medication(revision: 2, deleted: true))],
        ),
      );
      await repository.applyPage(
        scope: scope,
        page: _page(
          cursor: '1',
          nextCursor: '2',
          checkpoint: '3',
          changes: [_change('2', _medication(revision: 1))],
        ),
      );

      var stored = await database
          .select(database.syncedMedications)
          .getSingle();
      expect(stored.revision, 2);
      expect(stored.deletedAt, isNotNull);

      await repository.applyPage(
        scope: scope,
        page: _page(
          cursor: '2',
          nextCursor: '3',
          checkpoint: '3',
          changes: [_change('3', _medication(revision: 3))],
        ),
      );
      stored = await database.select(database.syncedMedications).getSingle();
      expect(stored.revision, 3);
      expect(stored.deletedAt, isNull);
    },
  );
}

Future<void> _seedAuthorizedScope(
  DoseyDatabase database,
  AuthorizedCachedSyncScope scope,
) async {
  await database
      .into(database.cachedRobotInstallations)
      .insert(
        CachedRobotInstallationsCompanion.insert(
          accountId: scope.accountId,
          robotId: scope.robotId,
          displayName: 'Kitchen Robot',
          ownerAccountId: scope.accountId,
          currentRole: 'owner',
          confirmedAt: DateTime.utc(2040),
        ),
      );
  await database
      .into(database.cachedHouseholdMembers)
      .insert(
        CachedHouseholdMembersCompanion.insert(
          accountId: scope.accountId,
          memberAccountId: scope.accountId,
          label: 'Owner',
          role: 'owner',
          position: 0,
        ),
      );
}

PullPageContract _page({
  String? cursor,
  required String checkpoint,
  required String nextCursor,
  required List<PullChangeContract> changes,
}) => PullPageContract.fromJson(
  PullPageContract(
    robotId: 'robot-1',
    cursor: cursor,
    checkpoint: checkpoint,
    nextCursor: nextCursor,
    hasMore: nextCursor != checkpoint,
    changes: changes,
  ).toJson(),
);

PullChangeContract _change(String cursor, Object record) => PullChangeContract(
  cursor: cursor,
  entityType: switch (record) {
    MedicationContract() => EntityTypeContract.medication,
    MedicationScheduleContract() => EntityTypeContract.schedule,
    DoseEventContract() => EntityTypeContract.doseEvent,
    _ => throw ArgumentError.value(record),
  },
  entityId: switch (record) {
    MedicationContract value => value.id,
    MedicationScheduleContract value => value.id,
    DoseEventContract value => value.id,
    _ => throw ArgumentError.value(record),
  },
  operation: switch (record) {
    MedicationContract(deletedAt: final deletedAt) =>
      deletedAt == null
          ? MutationOperationContract.upsert
          : MutationOperationContract.delete,
    MedicationScheduleContract(deletedAt: final deletedAt) =>
      deletedAt == null
          ? MutationOperationContract.upsert
          : MutationOperationContract.delete,
    DoseEventContract() => MutationOperationContract.append,
    _ => throw ArgumentError.value(record),
  },
  record: record,
);

MedicationContract _medication({
  required int revision,
  String name = 'Aspirin',
  bool deleted = false,
}) => MedicationContract(
  id: 'medication-1',
  householdId: 'robot-1',
  name: name,
  pillType: PillTypeContract.pill,
  instructions: 'With water',
  revision: revision,
  deletedAt: deleted ? '2040-01-02T10:00:00.000Z' : null,
  updatedAt: '2040-01-02T10:00:00.000Z',
);

MedicationScheduleContract _schedule({required int revision}) =>
    MedicationScheduleContract(
      id: 'schedule-1',
      householdId: 'robot-1',
      medicationId: 'medication-1',
      label: 'Morning',
      hour: 8,
      minute: 30,
      timezoneId: 'UTC',
      enabled: true,
      revision: revision,
      deletedAt: null,
      updatedAt: '2040-01-02T10:00:00.000Z',
    );

DoseEventContract _doseEvent() => DoseEventContract(
  id: 'event-1',
  householdId: 'robot-1',
  medicationId: 'medication-1',
  occurrence: const OccurrenceRefContract(
    occurrenceId: 'schedule-1:1:2040-01-02T08:30:00.000Z',
    scheduleId: 'schedule-1',
    scheduleRevision: 1,
    scheduledAt: '2040-01-02T08:30:00.000Z',
    localDate: '2040-01-02',
    timezoneId: 'UTC',
  ),
  kind: DoseEventKindContract.takenConfirmed,
  occurredAt: '2040-01-02T08:31:00.000Z',
  actorAccountId: 'caregiver-1',
);
