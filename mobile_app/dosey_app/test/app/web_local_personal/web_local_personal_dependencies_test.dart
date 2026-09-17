import 'dart:async';

import 'package:dosey_app/app/web_local_personal/web_local_personal_startup.dart';
import 'package:dosey_app/core/admin/admin_audit_event_factory.dart';
import 'package:dosey_app/core/admin/protected_admin_action.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:dosey_app/features/shared/personal_setup_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'local schedules reject absent medication/profile and deferred deletion without effects',
    () async {
      final db = DoseyDatabase.inMemory();
      addTearDown(db.close);
      final setup = PersonalSetupDependencies.local(db);
      final now = DateTime.utc(2026, 9, 15);
      final prescription = Prescription(
        id: 'fictional',
        name: 'Fictional blue',
        pillType: PillType.pill,
        availableDoses: 8,
        createdAt: now,
        updatedAt: now,
      );
      final schedule = ReminderSchedule(
        id: 'fictional-schedule',
        label: 'Fictional blue',
        prescriptionId: prescription.id,
        hour: 8,
        minute: 0,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      );
      await expectLater(
        setup.reminders.upsertSchedule(schedule),
        throwsStateError,
      );
      await setup.prescriptions.upsertPrescription(prescription);
      await expectLater(
        setup.reminders.upsertSchedule(schedule.copyWith(profileId: 'absent')),
        throwsStateError,
      );
      await db.customStatement(
        "INSERT INTO app_settings (key, value, updated_at) VALUES ('deferred_deleted_prescription:fictional', 'true', 1)",
      );
      await expectLater(
        setup.reminders.upsertSchedule(schedule),
        throwsStateError,
      );
      await expectLater(
        setup.prescriptions.upsertPrescription(
          prescription.copyWith(name: 'Stale'),
          expectedState: prescription,
        ),
        throwsStateError,
      );
      expect(await db.select(db.reminderSchedules).get(), isEmpty);
      expect(await db.select(db.adminAuditEvents).get(), isEmpty);
      expect(
        (await db.select(db.prescriptions).get()).single.name,
        'Fictional blue',
      );
    },
  );
  for (final operation in ['edit', 'refill', 'delete', 'schedule']) {
    test(
      'local $operation rolls back mutation and audit on late failure then retries',
      () async {
        final db = DoseyDatabase.inMemory();
        addTearDown(db.close);
        final setup = PersonalSetupDependencies.local(db);
        final now = DateTime.utc(2026, 9, 15);
        final prescription = Prescription(
          id: 'fictional',
          name: 'Fictional blue',
          pillType: PillType.pill,
          availableDoses: 8,
          createdAt: now,
          updatedAt: now,
        );
        final schedule = ReminderSchedule(
          id: 'fictional-schedule',
          label: 'Fictional blue',
          prescriptionId: prescription.id,
          hour: 8,
          minute: 0,
          isEnabled: true,
          createdAt: now,
          updatedAt: now,
        );
        await setup.prescriptions.upsertPrescription(prescription);
        await setup.reminders.upsertSchedule(schedule);
        await setup.prescriptions.addRefill(
          prescriptionId: prescription.id,
          doseCount: 2,
          occurredAt: now,
        );
        final before = await db
            .customSelect('SELECT * FROM prescriptions')
            .get();
        await db.customStatement(
          "CREATE TRIGGER reject_audit BEFORE INSERT ON admin_audit_events BEGIN SELECT RAISE(ABORT, 'fictional audit failure'); END",
        );
        Future<void> mutate() async {
          final result = await setup.run<void>(
            requestPin: () async => null,
            action: (actor) async {
              final factory = const AdminAuditEventFactory();
              final role = await setup.sourceRole();
              switch (operation) {
                case 'edit':
                  await setup.prescriptions.upsertPrescription(
                    prescription.copyWith(name: 'Fictional edited'),
                    auditEvent: factory.prescriptionSaved(
                      actor: actor,
                      sourceDeviceRole: role,
                      targetId: prescription.id,
                      summary: 'Fictional edit',
                    ),
                  );
                case 'refill':
                  await setup.prescriptions.addRefill(
                    prescriptionId: prescription.id,
                    doseCount: 3,
                    occurredAt: now.add(const Duration(seconds: 1)),
                    auditEvent: factory.prescriptionRefillAdded(
                      actor: actor,
                      sourceDeviceRole: role,
                      targetId: prescription.id,
                      summary: 'Fictional refill',
                    ),
                  );
                case 'delete':
                  await setup.prescriptions.deletePrescription(
                    prescription.id,
                    auditEvent: factory.prescriptionDeleted(
                      actor: actor,
                      sourceDeviceRole: role,
                      targetId: prescription.id,
                      summary: 'Fictional delete',
                    ),
                  );
                case 'schedule':
                  await setup.reminders.upsertSchedule(
                    schedule.copyWith(minute: 15),
                    auditEvent: factory.scheduleSaved(
                      actor: actor,
                      sourceDeviceRole: role,
                      targetId: schedule.id,
                      summary: 'Fictional schedule',
                    ),
                  );
              }
            },
          );
          expect(result.isSuccess, isTrue);
        }

        await expectLater(mutate(), throwsA(isA<Exception>()));
        expect(
          (await db.customSelect('SELECT * FROM prescriptions').get())
              .single
              .data,
          before.single.data,
        );
        expect((await db.select(db.reminderSchedules).get()).single.minute, 0);
        expect(await db.select(db.prescriptionRefills).get(), hasLength(1));
        expect(await db.select(db.adminAuditEvents).get(), isEmpty);
        await db.customStatement('DROP TRIGGER reject_audit');
        await mutate();
        expect(await db.select(db.adminAuditEvents).get(), hasLength(1));
        if (operation == 'delete') {
          expect(await db.select(db.reminderSchedules).get(), isEmpty);
          expect(await db.select(db.prescriptionRefills).get(), isEmpty);
        }
      },
    );
  }
  test(
    'ready initializes an explicit active local profile when none exists',
    () async {
      final db = DoseyDatabase.inMemory();
      await db.delete(db.scheduleProfiles).go();
      final owner = WebLocalPersonalStartup(
        bootstrap: () async => WebStorageReady(
          database: db,
          classification: classifyWebStorage(
            WebStorageImplementation.opfsShared,
          ),
          missingFeatures: const {},
        ),
      );
      addTearDown(owner.shutdown);
      await owner.start();
      expect(owner.result, isA<WebStorageReady>());
      final profiles = await owner.setup!.scheduleProfiles
          .watchProfiles()
          .first;
      expect(profiles, hasLength(1));
      expect(profiles.single.id, ScheduleProfile.defaultProfileId);
      expect(profiles.single.isActive, isTrue);
    },
  );

  test(
    'profile initialization preserves a selected routine and repairs an inactive one',
    () async {
      final db = DoseyDatabase.inMemory();
      addTearDown(db.close);
      final setup = PersonalSetupDependencies.local(db);
      await setup.initializeLocalProfile();
      final original =
          (await setup.scheduleProfiles.watchProfiles().first).single;
      await setup.scheduleProfiles.upsertProfile(
        original.copyWith(name: 'Fictional routine', isActive: false),
      );
      await setup.initializeLocalProfile();
      final active = (await setup.scheduleProfiles.watchActiveProfile().first)!;
      expect(active.id, original.id);
      expect(active.name, 'Fictional routine');
      await setup.initializeLocalProfile();
      expect(await setup.scheduleProfiles.watchProfiles().first, hasLength(1));
    },
  );

  test(
    'profile initialization failure never exposes a ready editable scope',
    () async {
      final db = DoseyDatabase.inMemory();
      await db.delete(db.scheduleProfiles).go();
      await db.customStatement(
        "CREATE TRIGGER reject_profile BEFORE INSERT ON schedule_profiles BEGIN SELECT RAISE(ABORT, 'fictional profile failure'); END",
      );
      final owner = WebLocalPersonalStartup(
        bootstrap: () async => WebStorageReady(
          database: db,
          classification: classifyWebStorage(
            WebStorageImplementation.opfsShared,
          ),
          missingFeatures: const {},
        ),
      );
      addTearDown(owner.shutdown);
      await owner.start();
      expect(owner.setup, isNull);
      final result = owner.result as WebStorageStartupRecovery;
      expect(result.error.toString(), contains('fictional profile failure'));
      expect(result.cleanup, WebStorageCleanup.completed);
      expect(owner.loading, isFalse);
    },
  );

  test(
    'local PIN cancel/wrong authorize nothing; correct PIN audits once; drain rejects new work and awaits pending',
    () async {
      final db = DoseyDatabase.inMemory();
      addTearDown(db.close);
      final setup = PersonalSetupDependencies.local(db);
      await LocalAppSettingsRepository(
        db,
        defaultRole: AppDeviceRole.webPersonal,
      ).setActionPin('1234');
      final entered = Completer<void>();
      final release = Completer<void>();
      final now = DateTime.utc(2026, 9, 15);
      var calls = 0;
      Future<void> save(actor) async {
        calls++;
        expect(actor.actorLabel, 'local admin');
        expect(actor.actorUserId, isNull);
        entered.complete();
        await release.future;
        await setup.prescriptions.upsertPrescription(
          Prescription(
            id: 'fictional',
            name: 'Fictional blue',
            pillType: PillType.pill,
            availableDoses: 8,
            createdAt: now,
            updatedAt: now,
          ),
          auditEvent: const AdminAuditEventFactory().prescriptionSaved(
            actor: actor,
            sourceDeviceRole: await setup.sourceRole(),
            targetId: 'fictional',
            summary: 'Fictional save',
            details: const {},
          ),
        );
      }

      for (final pin in <String?>[null, '9999']) {
        final result = await setup.run<void>(
          requestPin: () async => pin,
          action: save,
        );
        expect(result.isSuccess, isFalse);
        expect(calls, 0);
        expect(await db.select(db.prescriptions).get(), isEmpty);
        expect(await db.select(db.adminAuditEvents).get(), isEmpty);
      }
      final saving = setup.run<void>(
        requestPin: () async => '1234',
        action: save,
      );
      await entered.future;
      expect(
        (await setup.run<void>(
          requestPin: () async => '1234',
          action: save,
        )).status,
        ProtectedAdminActionStatus.cancelled,
      );
      var drained = false;
      final draining = setup.drain().then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      release.complete();
      expect((await saving).isSuccess, isTrue);
      await draining;
      expect(calls, 1);
      expect(await db.select(db.adminAuditEvents).get(), hasLength(1));
      expect(
        (await setup.run<void>(
          requestPin: () async => '1234',
          action: save,
        )).status,
        ProtectedAdminActionStatus.cancelled,
      );
    },
  );
}
