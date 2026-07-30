import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh schema stores occurrence event and pending mutation', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 7, 30, 22);

    await database.transaction(() async {
      await database
          .into(database.phoneDoseActionEvents)
          .insert(
            PhoneDoseActionEventsCompanion.insert(
              id: 'event-1',
              deviceId: 'device-1',
              occurrenceId: 'schedule-1:7:2026-07-30T22:00:00.000Z',
              scheduleId: 'schedule-1',
              scheduleRevision: 7,
              scheduledAt: now,
              localDate: '2026-07-30',
              timezoneId: 'America/Los_Angeles',
              medicationId: 'medication-1',
              kind: 'taken_confirmed',
              occurredAt: now,
              marksDoseTaken: true,
              idempotencyKey:
                  'dose-action:schedule-1:7:2026-07-30T22:00:00.000Z:taken_confirmed',
              createdAt: now,
            ),
          );
      await database
          .into(database.syncOutboxMutations)
          .insert(
            SyncOutboxMutationsCompanion.insert(
              mutationId: 'mutation-1',
              deviceId: 'device-1',
              idempotencyKey:
                  'dose-action:schedule-1:7:2026-07-30T22:00:00.000Z:taken_confirmed',
              entityType: 'dose_event',
              operation: 'append',
              entityId: 'event-1',
              baseRevision: const Value.absent(),
              payloadJson: '{"kind":"taken_confirmed"}',
              state: const Value('pending'),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    final event =
        (await database.select(database.phoneDoseActionEvents).get()).single;
    final mutation =
        (await database.select(database.syncOutboxMutations).get()).single;

    expect(event.occurrenceId, contains('schedule-1:7:'));
    expect(event.marksDoseTaken, isTrue);
    expect(mutation.state, 'pending');
    expect(mutation.baseRevision, isNull);
  });

  test('cursor and conflict seams persist without a transport', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 7, 30, 22);

    await database
        .into(database.syncCursors)
        .insert(
          SyncCursorsCompanion.insert(
            scopeKey: 'unlinked',
            robotId: const Value.absent(),
            cursor: const Value('cursor-4'),
            checkpoint: const Value('checkpoint-2'),
            updatedAt: now,
          ),
        );
    await database
        .into(database.syncConflicts)
        .insert(
          SyncConflictsCompanion.insert(
            mutationId: 'mutation-1',
            outcome: 'conflict',
            revision: const Value(4),
            cursor: const Value('cursor-5'),
            errorCode: const Value('revision_conflict'),
            conflictJson: const Value('{"serverRevision":4}'),
            createdAt: now,
          ),
        );

    final cursor = (await database.select(database.syncCursors).get()).single;
    final conflict =
        (await database.select(database.syncConflicts).get()).single;

    expect(cursor.robotId, isNull);
    expect(cursor.checkpoint, 'checkpoint-2');
    expect(conflict.outcome, 'conflict');
    expect(conflict.resolvedAt, isNull);
  });
}
