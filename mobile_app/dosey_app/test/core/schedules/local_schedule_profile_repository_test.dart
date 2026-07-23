import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/audit/local_admin_audit_repository.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'local schedule profile repository seeds one active default profile',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalScheduleProfileRepository(database);

      final profiles = await repository.watchProfiles().first;

      expect(profiles, hasLength(1));
      expect(profiles.single.id, ScheduleProfile.defaultProfileId);
      expect(profiles.single.name, 'Schedule 1');
      expect(profiles.single.isActive, isTrue);
      final active = await repository.watchActiveProfile().first;
      expect(active?.id, ScheduleProfile.defaultProfileId);
    },
  );

  test(
    'local schedule profile repository switches the active profile',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalScheduleProfileRepository(database);
      final createdAt = DateTime.utc(2026, 6, 9, 8);
      final travel = ScheduleProfile(
        id: 'travel',
        name: 'Travel',
        isActive: false,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      await repository.upsertProfile(travel);
      await repository.setActiveProfile('travel');

      final profiles = await repository.watchProfiles().first;
      final active = await repository.watchActiveProfile().first;
      expect(active?.id, 'travel');
      expect(profiles.where((profile) => profile.isActive), hasLength(1));
      expect(
        profiles.singleWhere((profile) => profile.id == 'travel').isActive,
        isTrue,
      );
      expect(
        profiles
            .singleWhere(
              (profile) => profile.id == ScheduleProfile.defaultProfileId,
            )
            .isActive,
        isFalse,
      );
    },
  );

  test('watchActiveProfile emits null when no profile is active', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalScheduleProfileRepository(database);
    final now = DateTime.utc(2026, 6, 9, 9);

    await database
        .update(database.scheduleProfiles)
        .write(
          ScheduleProfilesCompanion(
            isActive: const Value(false),
            updatedAt: Value(now),
          ),
        );

    expect(await repository.watchActiveProfile().first, isNull);
  });

  test('already-active profile still persists the audit event', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalScheduleProfileRepository(database);
    final auditEvent = AdminAuditEvent(
      id: 'audit-active-noop',
      eventType: AdminAuditEventType.activeScheduleProfileChanged,
      targetType: AdminAuditTargetType.scheduleProfile,
      targetId: ScheduleProfile.defaultProfileId,
      summary: 'Activated schedule profile.',
      actorType: AdminAuditActorType.localAdmin,
      actorLabel: 'Tester',
      sourceDeviceRole: 'androidRobot',
      occurredAt: DateTime.utc(2026, 6, 9, 10),
    );

    await repository.setActiveProfile(
      ScheduleProfile.defaultProfileId,
      auditEvent: auditEvent,
    );

    final auditEvents = await LocalAdminAuditRepository(
      database,
    ).watchRecentEvents(limit: 5).first;
    expect(auditEvents.map((event) => event.id), contains(auditEvent.id));
  });
}
