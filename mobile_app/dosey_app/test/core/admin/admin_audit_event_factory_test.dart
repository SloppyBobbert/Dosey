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

  test('household lifecycle audits use household targets', () {
    final occurredAt = DateTime.utc(2026, 7, 26, 14);

    final events = [
      factory.householdCreated(
        actor: actor,
        sourceDeviceRole: 'androidPersonal',
        targetId: 'robot-1',
        summary: 'Created household.',
        robotDisplayName: 'Kitchen Dosey',
        occurredAt: occurredAt,
      ),
      factory.householdInvitationGenerated(
        actor: actor,
        sourceDeviceRole: 'androidPersonal',
        targetId: 'robot-1',
        summary: 'Generated household invitation.',
        invitedEmail: 'member@example.com',
        expiresAt: DateTime.utc(2026, 7, 27, 14),
        occurredAt: occurredAt,
      ),
      factory.householdMemberRemoved(
        actor: actor,
        sourceDeviceRole: 'androidPersonal',
        targetId: 'robot-1',
        summary: 'Removed household member.',
        removedAccountId: 'member-1',
        removedLabel: 'Member Person',
        occurredAt: occurredAt,
      ),
      factory.householdLeft(
        actor: actor,
        sourceDeviceRole: 'iosPersonal',
        targetId: 'robot-1',
        summary: 'Left household.',
        occurredAt: occurredAt,
      ),
    ];

    expect(
      events.map((event) => event.eventType).toSet(),
      AdminAuditEventType.values
          .where(
            (type) => {
              AdminAuditEventType.householdCreated,
              AdminAuditEventType.householdInvitationGenerated,
              AdminAuditEventType.householdMemberRemoved,
              AdminAuditEventType.householdLeft,
            }.contains(type),
          )
          .toSet(),
    );
    for (final event in events) {
      expect(event.targetType, AdminAuditTargetType.household);
      expect(event.targetId, 'robot-1');
    }
  });

  test('household invitation audit cannot contain its plaintext code', () {
    final event = factory.householdInvitationGenerated(
      actor: actor,
      sourceDeviceRole: 'androidPersonal',
      targetId: 'robot-1',
      summary: 'Generated household invitation.',
      invitedEmail: 'member@example.com',
      expiresAt: DateTime.utc(2026, 7, 27, 14),
    );

    final details = jsonDecode(event.detailsJson!) as Map<String, Object?>;

    expect(details, {
      'invitedEmail': 'member@example.com',
      'expiresAt': '2026-07-27T14:00:00.000Z',
    });
    expect(event.detailsJson, isNot(contains('ABCD')));
    expect(event.detailsJson, isNot(contains('code')));
    expect(event.detailsJson, isNot(contains('digest')));
  });
}
