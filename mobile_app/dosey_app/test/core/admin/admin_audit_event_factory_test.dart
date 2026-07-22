import 'dart:convert';

import 'package:dosey_app/core/admin/admin_audit_event_factory.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const actor = AdminAuditActorIdentity(
    actorType: AdminAuditActorType.signedInUser,
    actorUserId: 'google:user-1',
    actorLabel: 'Dosey Admin (google)',
    actorProviderLabel: 'google',
  );
  const factory = AdminAuditEventFactory();

  test('schedule profile rename audit includes previous and new names', () {
    final event = factory.scheduleProfileSaved(
      actor: actor,
      sourceDeviceRole: 'androidRobot',
      targetId: 'profile-evening',
      summary: 'Renamed schedule profile from Evening to Weeknight.',
      details: const {
        'name': 'Weeknight',
        'isActive': true,
        'previousName': 'Evening',
        'newName': 'Weeknight',
        'created': false,
      },
      occurredAt: DateTime.utc(2026, 7, 22, 12),
    );

    final details = jsonDecode(event.detailsJson!) as Map<String, Object?>;

    expect(event.eventType, AdminAuditEventType.scheduleProfileSaved);
    expect(event.targetType, AdminAuditTargetType.scheduleProfile);
    expect(event.targetId, 'profile-evening');
    expect(details['previousName'], 'Evening');
    expect(details['newName'], 'Weeknight');
    expect(details['created'], isFalse);
  });

  test(
    'active schedule profile audit includes previous and new profile data',
    () {
      final event = factory.activeScheduleProfileChanged(
        actor: actor,
        sourceDeviceRole: 'androidRobot',
        targetId: 'profile-school',
        summary: 'Changed the active schedule profile from Weekend to School.',
        details: const {
          'previousActiveProfileId': 'profile-weekend',
          'previousActiveProfileName': 'Weekend',
          'newActiveProfileId': 'profile-school',
          'newActiveProfileName': 'School',
        },
        occurredAt: DateTime.utc(2026, 7, 22, 13),
      );

      final details = jsonDecode(event.detailsJson!) as Map<String, Object?>;

      expect(event.eventType, AdminAuditEventType.activeScheduleProfileChanged);
      expect(event.targetType, AdminAuditTargetType.scheduleProfile);
      expect(event.targetId, 'profile-school');
      expect(details['previousActiveProfileId'], 'profile-weekend');
      expect(details['previousActiveProfileName'], 'Weekend');
      expect(details['newActiveProfileId'], 'profile-school');
      expect(details['newActiveProfileName'], 'School');
    },
  );
}
