import 'package:drift/drift.dart';

import '../storage/dosey_database.dart';
import 'domain_contracts.dart';

class AuthorizedCachedSyncScope {
  const AuthorizedCachedSyncScope({
    required this.accountId,
    required this.robotId,
  });

  final String accountId;
  final String robotId;
}

class MedicationSyncPullState {
  const MedicationSyncPullState({
    required this.cursor,
    required this.checkpoint,
  });

  final String? cursor;
  final String? checkpoint;

  bool get isTerminal => cursor != null && cursor == checkpoint;
}

final class DriftMedicationSyncPullRepository {
  DriftMedicationSyncPullRepository(this._database);

  final DoseyDatabase _database;

  Future<MedicationSyncPullState?> readState(
    AuthorizedCachedSyncScope scope,
  ) async {
    final row =
        await (_database.select(_database.medicationSyncPullStates)..where(
              (row) =>
                  row.accountId.equals(scope.accountId) &
                  row.robotId.equals(scope.robotId),
            ))
            .getSingleOrNull();
    return row == null
        ? null
        : MedicationSyncPullState(
            cursor: row.cursor,
            checkpoint: row.checkpoint,
          );
  }

  Future<void> applyPage({
    required AuthorizedCachedSyncScope scope,
    required PullPageContract page,
  }) {
    final validatedPage = PullPageContract.fromJson(page.toJson());
    return _database.transaction(() async {
      await _requireAuthorizedCacheBinding(scope, validatedPage.robotId);
      final state =
          await (_database.select(_database.medicationSyncPullStates)..where(
                (row) =>
                    row.accountId.equals(scope.accountId) &
                    row.robotId.equals(scope.robotId),
              ))
              .getSingleOrNull();
      if (state == null) {
        if (validatedPage.cursor != null) {
          throw StateError('Initial pull page must start with a null cursor.');
        }
      } else if (validatedPage.cursor != state.cursor ||
          validatedPage.checkpoint != state.checkpoint) {
        throw StateError(
          'Pull page does not continue the persisted traversal.',
        );
      }

      for (final change in validatedPage.changes) {
        await _applyChange(scope, change);
      }
      await _database
          .into(_database.medicationSyncPullStates)
          .insertOnConflictUpdate(
            MedicationSyncPullStatesCompanion.insert(
              accountId: scope.accountId,
              robotId: scope.robotId,
              cursor: Value(validatedPage.nextCursor),
              checkpoint: Value(validatedPage.checkpoint),
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    });
  }

  Future<void> _requireAuthorizedCacheBinding(
    AuthorizedCachedSyncScope scope,
    String pageRobotId,
  ) async {
    if (scope.accountId.trim() != scope.accountId ||
        scope.accountId.isEmpty ||
        scope.robotId.trim() != scope.robotId ||
        scope.robotId.isEmpty ||
        pageRobotId != scope.robotId) {
      throw StateError('Medication sync scope is invalid.');
    }
    final installation =
        await (_database.select(_database.cachedRobotInstallations)..where(
              (row) =>
                  row.accountId.equals(scope.accountId) &
                  row.robotId.equals(scope.robotId),
            ))
            .getSingleOrNull();
    final member =
        await (_database.select(_database.cachedHouseholdMembers)..where(
              (row) =>
                  row.accountId.equals(scope.accountId) &
                  row.memberAccountId.equals(scope.accountId),
            ))
            .getSingleOrNull();
    if (installation == null ||
        member == null ||
        installation.currentRole != member.role) {
      throw StateError(
        'No authorized cached account and robot binding exists.',
      );
    }
  }

  Future<void> _applyChange(
    AuthorizedCachedSyncScope scope,
    PullChangeContract change,
  ) {
    return switch (change.record) {
      final MedicationContract medication => _applyMedication(
        scope,
        medication,
      ),
      final MedicationScheduleContract schedule => _applySchedule(
        scope,
        schedule,
      ),
      final DoseEventContract event => _applyDoseEvent(scope, event),
      _ => throw StateError('Unsupported pull record.'),
    };
  }

  Future<void> _applyMedication(
    AuthorizedCachedSyncScope scope,
    MedicationContract medication,
  ) async {
    final existing =
        await (_database.select(_database.syncedMedications)..where(
              (row) =>
                  row.accountId.equals(scope.accountId) &
                  row.robotId.equals(scope.robotId) &
                  row.id.equals(medication.id),
            ))
            .getSingleOrNull();
    if (existing != null && existing.revision > medication.revision) return;
    final deletedAt = _optionalTimestamp(medication.deletedAt);
    final updatedAt = _timestamp(medication.updatedAt);
    if (existing != null && existing.revision == medication.revision) {
      if (existing.name != medication.name ||
          existing.pillType != medication.pillType.wireValue ||
          existing.instructions != medication.instructions ||
          existing.deletedAt != deletedAt ||
          existing.updatedAt != updatedAt) {
        throw StateError('Medication content changed at the same revision.');
      }
      return;
    }
    await _database
        .into(_database.syncedMedications)
        .insertOnConflictUpdate(
          SyncedMedicationsCompanion.insert(
            accountId: scope.accountId,
            robotId: scope.robotId,
            id: medication.id,
            name: medication.name,
            pillType: medication.pillType.wireValue,
            instructions: Value(medication.instructions),
            revision: medication.revision,
            deletedAt: Value(deletedAt),
            updatedAt: updatedAt,
          ),
        );
  }

  Future<void> _applySchedule(
    AuthorizedCachedSyncScope scope,
    MedicationScheduleContract schedule,
  ) async {
    final existing =
        await (_database.select(_database.syncedMedicationSchedules)..where(
              (row) =>
                  row.accountId.equals(scope.accountId) &
                  row.robotId.equals(scope.robotId) &
                  row.id.equals(schedule.id),
            ))
            .getSingleOrNull();
    if (existing != null && existing.revision > schedule.revision) return;
    final deletedAt = _optionalTimestamp(schedule.deletedAt);
    final updatedAt = _timestamp(schedule.updatedAt);
    if (existing != null && existing.revision == schedule.revision) {
      if (existing.medicationId != schedule.medicationId ||
          existing.label != schedule.label ||
          existing.hour != schedule.hour ||
          existing.minute != schedule.minute ||
          existing.timezoneId != schedule.timezoneId ||
          existing.isEnabled != schedule.enabled ||
          existing.deletedAt != deletedAt ||
          existing.updatedAt != updatedAt) {
        throw StateError('Schedule content changed at the same revision.');
      }
      return;
    }
    await _database
        .into(_database.syncedMedicationSchedules)
        .insertOnConflictUpdate(
          SyncedMedicationSchedulesCompanion.insert(
            accountId: scope.accountId,
            robotId: scope.robotId,
            id: schedule.id,
            medicationId: schedule.medicationId,
            label: schedule.label,
            hour: schedule.hour,
            minute: schedule.minute,
            timezoneId: schedule.timezoneId,
            isEnabled: schedule.enabled,
            revision: schedule.revision,
            deletedAt: Value(deletedAt),
            updatedAt: updatedAt,
          ),
        );
  }

  Future<void> _applyDoseEvent(
    AuthorizedCachedSyncScope scope,
    DoseEventContract event,
  ) async {
    final existing =
        await (_database.select(_database.syncedDoseEvents)..where(
              (row) =>
                  row.accountId.equals(scope.accountId) &
                  row.robotId.equals(scope.robotId) &
                  row.id.equals(event.id),
            ))
            .getSingleOrNull();
    final scheduledAt = _timestamp(event.occurrence.scheduledAt);
    final occurredAt = _timestamp(event.occurredAt);
    if (existing != null) {
      if (existing.medicationId != event.medicationId ||
          existing.occurrenceId != event.occurrence.occurrenceId ||
          existing.scheduleId != event.occurrence.scheduleId ||
          existing.scheduleRevision != event.occurrence.scheduleRevision ||
          existing.scheduledAt != scheduledAt ||
          existing.localDate != event.occurrence.localDate ||
          existing.timezoneId != event.occurrence.timezoneId ||
          existing.kind != event.kind.wireValue ||
          existing.occurredAt != occurredAt ||
          existing.actorAccountId != event.actorAccountId) {
        throw StateError('Dose event content changed for an existing ID.');
      }
      return;
    }
    await _database
        .into(_database.syncedDoseEvents)
        .insert(
          SyncedDoseEventsCompanion.insert(
            accountId: scope.accountId,
            robotId: scope.robotId,
            id: event.id,
            medicationId: event.medicationId,
            occurrenceId: event.occurrence.occurrenceId,
            scheduleId: event.occurrence.scheduleId,
            scheduleRevision: event.occurrence.scheduleRevision,
            scheduledAt: scheduledAt,
            localDate: event.occurrence.localDate,
            timezoneId: event.occurrence.timezoneId,
            kind: event.kind.wireValue,
            occurredAt: occurredAt,
            actorAccountId: event.actorAccountId,
          ),
        );
  }

  static DateTime _timestamp(String value) => DateTime.parse(value).toUtc();

  static DateTime? _optionalTimestamp(String? value) =>
      value == null ? null : _timestamp(value);
}
