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
    return database.customStatement(
      '''
      INSERT INTO admin_audit_events (
        id,
        event_type,
        target_type,
        target_id,
        actor_type,
        actor_user_id,
        actor_label,
        source_device_role,
        summary,
        details_json,
        cloud_event_id,
        last_synced_at,
        occurred_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        _idFor(event),
        event.eventType.name,
        event.targetType.name,
        event.targetId,
        event.actorType.name,
        event.actorUserId,
        event.actorLabel,
        event.sourceDeviceRole,
        event.summary,
        event.detailsJson,
        event.cloudEventId,
        event.lastSyncedAt?.toUtc().millisecondsSinceEpoch,
        event.occurredAt.toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  Stream<List<AdminAuditEvent>> _watchEvents({int? limit}) {
    final sql = StringBuffer('''
      SELECT
        id,
        event_type,
        target_type,
        target_id,
        actor_type,
        actor_user_id,
        actor_label,
        source_device_role,
        summary,
        details_json,
        cloud_event_id,
        last_synced_at,
        occurred_at
      FROM admin_audit_events
      ORDER BY occurred_at DESC, id DESC
    ''');
    final variables = <Variable<Object>>[];
    if (limit != null) {
      sql.write(' LIMIT ?');
      variables.add(Variable<Object>(limit));
    }

    return _database
        .customSelect(sql.toString(), variables: variables, readsFrom: const {})
        .watch()
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  static String _idFor(AdminAuditEvent event) {
    final targetSuffix = event.targetId == null ? '' : ':${event.targetId}';
    return '${event.eventType.name}:${event.targetType.name}$targetSuffix:${event.occurredAt.toUtc().microsecondsSinceEpoch}';
  }

  static AdminAuditEvent _fromRow(QueryRow row) {
    return AdminAuditEvent(
      eventType: AdminAuditEventType.values.byName(
        row.read<String>('event_type'),
      ),
      targetType: AdminAuditTargetType.values.byName(
        row.read<String>('target_type'),
      ),
      targetId: row.readNullable<String>('target_id'),
      actorType: AdminAuditActorType.values.byName(
        row.read<String>('actor_type'),
      ),
      actorUserId: row.readNullable<String>('actor_user_id'),
      actorLabel: row.read<String>('actor_label'),
      sourceDeviceRole: row.read<String>('source_device_role'),
      summary: row.read<String>('summary'),
      detailsJson: row.readNullable<String>('details_json'),
      cloudEventId: row.readNullable<String>('cloud_event_id'),
      lastSyncedAt: _readNullableDateTime(row, 'last_synced_at'),
      occurredAt: _readDateTime(row, 'occurred_at'),
    );
  }

  static DateTime _readDateTime(QueryRow row, String column) {
    return DateTime.fromMillisecondsSinceEpoch(
      row.read<int>(column),
      isUtc: true,
    );
  }

  static DateTime? _readNullableDateTime(QueryRow row, String column) {
    final value = row.readNullable<int>(column);
    if (value == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
}
