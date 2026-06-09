import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

enum DoseLogEventKind { controllerDispenseSucceeded, doseTakenConfirmed, error }

class DoseLogEvent {
  const DoseLogEvent({
    required this.kind,
    required this.doseId,
    required this.occurredAt,
    required this.marksDoseTaken,
  });

  factory DoseLogEvent.controllerDispenseSucceeded({
    required String doseId,
    required DateTime occurredAt,
  }) {
    return DoseLogEvent(
      kind: DoseLogEventKind.controllerDispenseSucceeded,
      doseId: doseId,
      occurredAt: occurredAt,
      marksDoseTaken: false,
    );
  }

  final DoseLogEventKind kind;
  final String doseId;
  final DateTime occurredAt;
  final bool marksDoseTaken;
}

abstract interface class DoseLogRepository {
  Future<void> addEvent(DoseLogEvent event);

  Stream<List<DoseLogEvent>> watchEvents();
}

class DriftDoseLogRepository implements DoseLogRepository {
  const DriftDoseLogRepository(this._database);

  final DoseyDatabase _database;

  @override
  Future<void> addEvent(DoseLogEvent event) {
    return _database
        .into(_database.doseLogEvents)
        .insert(
          DoseLogEventsCompanion.insert(
            id: _idFor(event),
            kind: event.kind.name,
            doseId: event.doseId,
            occurredAt: event.occurredAt.toUtc(),
            marksDoseTaken: event.marksDoseTaken,
          ),
        );
  }

  @override
  Stream<List<DoseLogEvent>> watchEvents() {
    final query = _database.select(_database.doseLogEvents)
      ..orderBy([(event) => OrderingTerm.desc(event.occurredAt)]);

    return query.watch().map((events) => events.map(_fromRow).toList());
  }

  static String _idFor(DoseLogEvent event) {
    return '${event.kind.name}:${event.doseId}:${event.occurredAt.toUtc().microsecondsSinceEpoch}';
  }

  static DoseLogEvent _fromRow(DoseLogEventRow event) {
    return DoseLogEvent(
      kind: DoseLogEventKind.values.byName(event.kind),
      doseId: event.doseId,
      occurredAt: event.occurredAt.toUtc(),
      marksDoseTaken: event.marksDoseTaken,
    );
  }
}
