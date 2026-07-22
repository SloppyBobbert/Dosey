import 'package:dosey_app/core/audit/admin_audit_event.dart';

abstract interface class AdminAuditRepository {
  Future<void> addEvent(AdminAuditEvent event);

  Future<void> addEvents(Iterable<AdminAuditEvent> events);

  Stream<List<AdminAuditEvent>> watchEvents();

  Stream<List<AdminAuditEvent>> watchRecentEvents({int limit = 20});
}
