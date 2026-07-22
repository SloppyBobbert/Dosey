import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/admin_audit_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

class LocalAdminAuditRepository implements AdminAuditRepository {
  const LocalAdminAuditRepository(this._database);

  final DoseyDatabase _database;

  @override
  Future<void> addEvent(AdminAuditEvent event) {
    return insertEventIntoDatabase(_database, event);
  }

  @override
  Future<void> addEvents(Iterable<AdminAuditEvent> events) {
    return _database.transaction(() async {
      for (final event in events) {
        await insertEventIntoDatabase(_database, event);
      }
    });
  }

  @override
  Stream<List<AdminAuditEvent>> watchEvents() {
    return _watchEvents();
  }

  @override
  Stream<List<AdminAuditEvent>> watchRecentEvents({int limit = 20}) {
    return _watchEvents(limit: limit);
  }

  static Future<void> insertEventIntoDatabase(
    DoseyDatabase database,
    AdminAuditEvent event,
  ) {
    return database
        .into(database.adminAuditEvents)
        .insert(
          AdminAuditEventsCompanion.insert(
            id: event.id,
            eventType: event.eventType.name,
            targetType: event.targetType.name,
            targetId: Value(event.targetId),
            actorType: event.actorType.name,
            actorUserId: Value(event.actorUserId),
            actorLabel: event.actorLabel,
            sourceDeviceRole: event.sourceDeviceRole,
            summary: event.summary,
            detailsJson: Value(event.detailsJson),
            cloudEventId: Value(event.cloudEventId),
            lastSyncedAt: Value(event.lastSyncedAt?.toUtc()),
            occurredAt: event.occurredAt.toUtc(),
          ),
        );
  }

  Stream<List<AdminAuditEvent>> _watchEvents({int? limit}) {
    final query = _database.select(_database.adminAuditEvents)
      ..orderBy([
        (event) => OrderingTerm.desc(event.occurredAt),
        (event) => OrderingTerm.desc(event.id),
      ]);
    if (limit != null) {
      query.limit(limit);
    }

    return query.watch().map(
      (rows) => rows.map(_fromRow).toList(growable: false),
    );
  }

  static AdminAuditEvent _fromRow(AdminAuditEventRow row) {
    return AdminAuditEvent(
      id: row.id,
      eventType: AdminAuditEventType.values.byName(row.eventType),
      targetType: AdminAuditTargetType.values.byName(row.targetType),
      targetId: row.targetId,
      actorType: AdminAuditActorType.values.byName(row.actorType),
      actorUserId: row.actorUserId,
      actorLabel: row.actorLabel,
      sourceDeviceRole: row.sourceDeviceRole,
      summary: row.summary,
      detailsJson: row.detailsJson,
      cloudEventId: row.cloudEventId,
      lastSyncedAt: row.lastSyncedAt?.toUtc(),
      occurredAt: row.occurredAt.toUtc(),
    );
  }
}
