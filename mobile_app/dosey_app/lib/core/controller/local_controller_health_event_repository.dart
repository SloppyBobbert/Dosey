import 'dart:math';

import 'package:dosey_app/core/controller/controller_health_supervisor.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

typedef ControllerHealthEventIdGenerator =
    String Function(ControllerHealthEventType eventType, DateTime occurredAt);

class ControllerHealthEvent {
  const ControllerHealthEvent({
    required this.id,
    required this.type,
    required this.occurredAt,
    this.details,
  });

  final String id;
  final ControllerHealthEventType type;
  final DateTime occurredAt;
  final String? details;
}

class LocalControllerHealthEventRepository
    implements ControllerHealthEventSink {
  LocalControllerHealthEventRepository(
    this._database, {
    this.retentionLimit = 100,
    Random? random,
    ControllerHealthEventIdGenerator? idGenerator,
  }) : assert(retentionLimit > 0),
       _random = random ?? Random.secure(),
       // Public parameter name is part of the repository's testable API.
       // ignore: prefer_initializing_formals
       _idGenerator = idGenerator;

  final DoseyDatabase _database;
  final int retentionLimit;
  final Random _random;
  final ControllerHealthEventIdGenerator? _idGenerator;

  @override
  Future<void> recordControllerHealthEvent(
    ControllerHealthEventType type, {
    required DateTime occurredAt,
    String? details,
  }) async {
    final normalizedAt = occurredAt.toUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.controllerHealthEvents)
          .insert(
            ControllerHealthEventsCompanion.insert(
              id: _nextId(type, normalizedAt),
              eventType: type.name,
              occurredAt: normalizedAt,
              details: Value(details),
            ),
          );

      final expired =
          await (_database.selectOnly(_database.controllerHealthEvents)
                ..addColumns([_database.controllerHealthEvents.id])
                ..orderBy([
                  OrderingTerm.desc(
                    _database.controllerHealthEvents.occurredAt,
                  ),
                  OrderingTerm.desc(_database.controllerHealthEvents.id),
                ])
                ..limit(-1, offset: retentionLimit))
              .map((row) => row.read(_database.controllerHealthEvents.id)!)
              .get();
      if (expired.isNotEmpty) {
        await (_database.delete(
          _database.controllerHealthEvents,
        )..where((event) => event.id.isIn(expired))).go();
      }
    });
  }

  Stream<List<ControllerHealthEvent>> watchRecentEvents({int limit = 20}) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }
    final query = _database.select(_database.controllerHealthEvents)
      ..orderBy([
        (event) => OrderingTerm.desc(event.occurredAt),
        (event) => OrderingTerm.desc(event.id),
      ])
      ..limit(limit);
    return query.watch().map(
      (rows) => rows
          .map((row) {
            final type = ControllerHealthEventType.values
                .where((value) => value.name == row.eventType)
                .firstOrNull;
            if (type == null) return null;
            return ControllerHealthEvent(
              id: row.id,
              type: type,
              occurredAt: row.occurredAt.toUtc(),
              details: row.details,
            );
          })
          .whereType<ControllerHealthEvent>()
          .toList(),
    );
  }

  String _nextId(ControllerHealthEventType type, DateTime occurredAt) {
    return _idGenerator?.call(type, occurredAt) ??
        'health-${occurredAt.microsecondsSinceEpoch}-'
            '${_random.nextInt(1 << 32).toRadixString(16)}';
  }
}
