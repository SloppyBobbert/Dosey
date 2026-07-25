import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:dosey_app/core/controller/local_controller_health_event_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'health transitions persist newest first without command sessions',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      var id = 0;
      final repository = LocalControllerHealthEventRepository(
        database,
        idGenerator: (_, _) => 'health-${id++}',
      );
      final first = DateTime.utc(2040, 1, 2, 8);

      await repository.recordControllerHealthEvent(
        ControllerHealthEventType.offline,
        occurredAt: first,
        details: 'missed',
      );
      await repository.recordControllerHealthEvent(
        ControllerHealthEventType.recovered,
        occurredAt: first.add(const Duration(seconds: 2)),
      );

      final events = await repository.watchRecentEvents().first;
      final commandSessions = await database
          .select(database.controllerCommandSessions)
          .get();
      expect(events.map((event) => event.type), [
        ControllerHealthEventType.recovered,
        ControllerHealthEventType.offline,
      ]);
      expect(events.last.details, 'missed');
      expect(commandSessions, isEmpty);
    },
  );

  test('health journal retains only its configured maximum', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    var id = 0;
    final repository = LocalControllerHealthEventRepository(
      database,
      retentionLimit: 3,
      idGenerator: (_, _) => 'health-${id++}',
    );
    final start = DateTime.utc(2040, 1, 2, 8);

    for (var index = 0; index < 5; index++) {
      await repository.recordControllerHealthEvent(
        ControllerHealthEventType.offline,
        occurredAt: start.add(Duration(seconds: index)),
        details: '$index',
      );
    }

    final events = await repository.watchRecentEvents(limit: 10).first;
    expect(events.map((event) => event.details), ['4', '3', '2']);
  });

  test(
    'health journal retention is deterministic for equal timestamps',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      var id = 0;
      final repository = LocalControllerHealthEventRepository(
        database,
        retentionLimit: 3,
        idGenerator: (_, _) => 'health-${id++}',
      );
      final occurredAt = DateTime.utc(2040, 1, 2, 8);

      for (var index = 0; index < 5; index++) {
        await repository.recordControllerHealthEvent(
          ControllerHealthEventType.offline,
          occurredAt: occurredAt,
          details: '$index',
        );
      }

      final events = await repository.watchRecentEvents(limit: 10).first;
      expect(events.map((event) => event.id), [
        'health-4',
        'health-3',
        'health-2',
      ]);
      expect(events.map((event) => event.details), ['4', '3', '2']);
    },
  );

  test('unknown stored health event types do not stop the stream', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalControllerHealthEventRepository(database);
    final occurredAt = DateTime.utc(2040, 1, 2, 8);
    await database
        .into(database.controllerHealthEvents)
        .insert(
          ControllerHealthEventsCompanion.insert(
            id: 'unknown',
            eventType: 'future_event',
            occurredAt: occurredAt.add(const Duration(seconds: 1)),
          ),
        );
    await database
        .into(database.controllerHealthEvents)
        .insert(
          ControllerHealthEventsCompanion.insert(
            id: 'known',
            eventType: ControllerHealthEventType.offline.name,
            occurredAt: occurredAt,
            details: const Value('known event'),
          ),
        );

    final events = await repository.watchRecentEvents().first;

    expect(events, hasLength(1));
    expect(events.single.id, 'known');
    expect(events.single.type, ControllerHealthEventType.offline);
  });
}
