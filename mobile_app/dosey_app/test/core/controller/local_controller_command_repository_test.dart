import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'controller command sessions and ordered events persist in the db',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalControllerCommandRepository(database);
      final createdAt = DateTime.utc(2026, 7, 10, 8);
      final ackAt = createdAt.add(const Duration(seconds: 5));
      final doneAt = createdAt.add(const Duration(seconds: 10));

      final session = await repository.createSession(
        commandType: ControllerCommandType.dispenseNext,
        doseId: 'dose-1',
        scheduleId: 'schedule-1',
        slotId: 'slot-7',
        now: createdAt,
      );

      await repository.appendEvent(
        session.id,
        ControllerCommandEventType.commandSent,
        occurredAt: createdAt,
        details: 'queued',
      );
      await repository.appendEvent(
        session.id,
        ControllerCommandEventType.ack,
        occurredAt: ackAt,
      );
      await repository.appendEvent(
        session.id,
        ControllerCommandEventType.servoDone,
        occurredAt: doneAt,
        details: 'advance complete',
      );

      final unresolved = await repository.getUnresolvedSessions();
      final events = await repository.getEventsForSession(session.id);

      expect(unresolved, hasLength(1));
      expect(unresolved.single.commandType, ControllerCommandType.dispenseNext);
      expect(unresolved.single.doseId, 'dose-1');
      expect(unresolved.single.scheduleId, 'schedule-1');
      expect(unresolved.single.slotId, 'slot-7');
      expect(events.map((event) => event.sequence), [1, 2, 3]);
      expect(events.map((event) => event.eventType), [
        ControllerCommandEventType.commandSent,
        ControllerCommandEventType.ack,
        ControllerCommandEventType.servoDone,
      ]);
      expect(events.first.details, 'queued');
      expect(events.last.details, 'advance complete');
    },
  );

  test(
    'accepted then timed out sessions stay unresolved and recoverable',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalControllerCommandRepository(database);
      final createdAt = DateTime.utc(2026, 7, 10, 9);
      final acceptedAt = createdAt.add(const Duration(seconds: 2));
      final timedOutAt = createdAt.add(const Duration(minutes: 2));

      final session = await repository.createSession(
        commandType: ControllerCommandType.heartbeat,
        now: createdAt,
      );

      await repository.updateSessionState(
        session.id,
        ControllerCommandSessionState.accepted,
        acceptedAt: acceptedAt,
        updatedAt: acceptedAt,
      );
      await repository.updateSessionState(
        session.id,
        ControllerCommandSessionState.timedOut,
        failureReason: ControllerCommandFailureReason.disconnect,
        updatedAt: timedOutAt,
      );

      final unresolved = await repository.getUnresolvedSessions();

      expect(unresolved, hasLength(1));
      expect(unresolved.single.id, session.id);
      expect(unresolved.single.state, ControllerCommandSessionState.timedOut);
      expect(
        unresolved.single.failureReason,
        ControllerCommandFailureReason.disconnect,
      );
      expect(unresolved.single.acceptedAt, acceptedAt);
      expect(unresolved.single.resolvedAt, isNull);

      await expectLater(
        repository.watchUnresolvedSessions(),
        emits(
          contains(
            isA<ControllerCommandSession>().having(
              (session) => session.state,
              'state',
              ControllerCommandSessionState.timedOut,
            ),
          ),
        ),
      );
    },
  );

  test(
    'concurrent sessions created at the same time keep unique ids',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalControllerCommandRepository(database);
      final createdAt = DateTime.utc(2026, 7, 10, 10);

      final sessions = await Future.wait(
        List.generate(
          8,
          (_) => repository.createSession(
            commandType: ControllerCommandType.dispenseTest,
            now: createdAt,
          ),
        ),
      );

      expect(sessions.map((session) => session.id).toSet(), hasLength(8));
    },
  );

  test(
    'succeeded sessions resolve and drop out of unresolved queries',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalControllerCommandRepository(database);
      final createdAt = DateTime.utc(2026, 7, 10, 11);
      final acceptedAt = createdAt.add(const Duration(seconds: 1));
      final resolvedAt = createdAt.add(const Duration(seconds: 6));

      final session = await repository.createSession(
        commandType: ControllerCommandType.dispenseNext,
        now: createdAt,
      );

      await repository.updateSessionState(
        session.id,
        ControllerCommandSessionState.accepted,
        acceptedAt: acceptedAt,
        updatedAt: acceptedAt,
      );
      await repository.updateSessionState(
        session.id,
        ControllerCommandSessionState.succeeded,
        updatedAt: resolvedAt,
      );

      final unresolved = await repository.getUnresolvedSessions();
      final persisted = await repository.getSession(session.id);

      expect(unresolved, isEmpty);
      expect(persisted.state, ControllerCommandSessionState.succeeded);
      expect(persisted.acceptedAt, acceptedAt);
      expect(persisted.resolvedAt, resolvedAt);
      expect(persisted.failureReason, isNull);
    },
  );

  test(
    'latest relevant session prefers unresolved work over newer resolved history',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalControllerCommandRepository(database);
      final createdAt = DateTime.utc(2026, 7, 10, 12);
      final timedOutAt = createdAt.add(const Duration(minutes: 2));
      final succeededAt = createdAt.add(const Duration(minutes: 5));

      final timedOutSession = await repository.createSession(
        commandType: ControllerCommandType.dispenseNext,
        now: createdAt,
      );
      await repository.updateSessionState(
        timedOutSession.id,
        ControllerCommandSessionState.timedOut,
        updatedAt: timedOutAt,
      );

      final succeededSession = await repository.createSession(
        commandType: ControllerCommandType.dispenseTest,
        now: succeededAt,
      );
      await repository.updateSessionState(
        succeededSession.id,
        ControllerCommandSessionState.succeeded,
        updatedAt: succeededAt,
      );

      expect(
        await repository.getLatestRelevantSession(),
        isA<ControllerCommandSession>()
            .having((session) => session.id, 'id', timedOutSession.id)
            .having(
              (session) => session.state,
              'state',
              ControllerCommandSessionState.timedOut,
            ),
      );

      await expectLater(
        repository.watchLatestRelevantSession(),
        emits(
          isA<ControllerCommandSession>()
              .having((session) => session.id, 'id', timedOutSession.id)
              .having(
                (session) => session.state,
                'state',
                ControllerCommandSessionState.timedOut,
              ),
        ),
      );
    },
  );

  test(
    'latest relevant session falls back to the latest row when nothing is unresolved',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalControllerCommandRepository(database);
      final createdAt = DateTime.utc(2026, 7, 10, 13);

      final olderSucceeded = await repository.createSession(
        commandType: ControllerCommandType.dispenseNext,
        now: createdAt,
      );
      await repository.updateSessionState(
        olderSucceeded.id,
        ControllerCommandSessionState.succeeded,
        updatedAt: createdAt.add(const Duration(minutes: 1)),
      );

      final newerSucceeded = await repository.createSession(
        commandType: ControllerCommandType.dispenseTest,
        now: createdAt.add(const Duration(minutes: 2)),
      );
      await repository.updateSessionState(
        newerSucceeded.id,
        ControllerCommandSessionState.succeeded,
        updatedAt: createdAt.add(const Duration(minutes: 3)),
      );

      final latest = await repository.getLatestRelevantSession();

      expect(latest?.id, newerSucceeded.id);
      expect(latest?.state, ControllerCommandSessionState.succeeded);
    },
  );
}
