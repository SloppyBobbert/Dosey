import 'dart:convert';

import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

class DemoDataRepository {
  DemoDataRepository(
    this._database, {
    required DateTime seedTime,
    required this.deviceRole,
  }) : seedTime = seedTime.toUtc() {
    if (!_database.isDemo) {
      throw ArgumentError('Demo data requires a demo-only database.');
    }
  }

  static const profileId = 'demo:profile';
  static const prescriptionId = 'demo:prescription';
  static const scheduleId = 'demo:schedule';
  static const loadSessionId = 'demo:load-session';
  static const loadSlotId = 'demo:load-session:1';

  final DoseyDatabase _database;
  final DateTime seedTime;
  final AppDeviceRole deviceRole;

  Future<void> resetAndSeed() {
    return _database.transaction(() async {
      await _clearAllData();
      await _seedSettings();
      await _seedDoseData();
    });
  }

  Future<void> _clearAllData() async {
    await _database.delete(_database.adminAuditEvents).go();
    await _database.delete(_database.controllerCommandEvents).go();
    await _database.delete(_database.controllerCommandSessions).go();
    await _database.delete(_database.doseLogEvents).go();
    await _database.delete(_database.medicationShortageAlerts).go();
    await _database.delete(_database.carouselLoadSlotSnapshots).go();
    await _database.delete(_database.carouselLoadSessions).go();
    await _database.delete(_database.carouselSlots).go();
    await _database.delete(_database.carouselStates).go();
    await _database.delete(_database.reminderSchedules).go();
    await _database.delete(_database.prescriptionRefills).go();
    await _database.delete(_database.prescriptions).go();
    await _database.delete(_database.scheduleProfiles).go();
    await _database.delete(_database.authSessions).go();
    await _database.delete(_database.appSettings).go();
  }

  Future<void> _seedSettings() async {
    await _database.batch((batch) {
      for (final setting in <String, String>{
        'device_role': deviceRole.storageValue,
        'onboarding_completed': 'true',
        'safety_acknowledged': 'true',
      }.entries) {
        batch.insert(
          _database.appSettings,
          AppSettingsCompanion.insert(
            key: setting.key,
            value: setting.value,
            updatedAt: seedTime,
          ),
        );
      }
    });
  }

  Future<void> _seedDoseData() async {
    final scheduledAt = DateTime.utc(
      seedTime.year,
      seedTime.month,
      seedTime.day,
      8,
      30,
    );
    await _database
        .into(_database.scheduleProfiles)
        .insert(
          ScheduleProfilesCompanion.insert(
            id: profileId,
            name: 'FAKE Demo Routine',
            isActive: true,
            createdAt: seedTime,
            updatedAt: seedTime,
          ),
        );
    await _database
        .into(_database.prescriptions)
        .insert(
          PrescriptionsCompanion.insert(
            id: prescriptionId,
            name: 'FAKE Demo Tablets',
            pillType: 'tablet',
            remainingDoses: const Value(14),
            guidedPillIcon: const Value('tablet'),
            availableDoses: const Value(13),
            loadedDoses: const Value(1),
            doseInstructions: const Value('FAKE DATA - take one demo dose'),
            createdAt: seedTime,
            updatedAt: seedTime,
          ),
        );
    await _database
        .into(_database.reminderSchedules)
        .insert(
          ReminderSchedulesCompanion.insert(
            id: scheduleId,
            label: 'FAKE Demo Morning Dose',
            prescriptionId: const Value(prescriptionId),
            profileId: const Value(profileId),
            hour: 8,
            minute: 30,
            isEnabled: true,
            createdAt: seedTime,
            updatedAt: seedTime,
          ),
        );
    await _database
        .into(_database.carouselLoadSessions)
        .insert(
          CarouselLoadSessionsCompanion.insert(
            id: loadSessionId,
            profileId: profileId,
            mode: 'full_load',
            status: 'confirmed',
            planCreatedAt: Value(seedTime),
            startedAt: Value(seedTime),
            confirmedAt: Value(seedTime),
            positionBefore: 0,
            positionAfter: 0,
            createdAt: seedTime,
            updatedAt: seedTime,
          ),
        );
    await _database
        .into(_database.carouselLoadSlotSnapshots)
        .insert(
          CarouselLoadSlotSnapshotsCompanion.insert(
            id: loadSlotId,
            sessionId: loadSessionId,
            slotNumber: 1,
            status: 'loaded',
            scheduledAt: Value(scheduledAt),
            bundleKey: const Value('demo:bundle'),
            scheduleIdsJson: jsonEncode(<String>[scheduleId]),
            prescriptionIdsJson: jsonEncode(<String>[prescriptionId]),
            prescriptionNamesJson: jsonEncode(<String>['FAKE Demo Tablets']),
            pillIconsJson: jsonEncode(<String>['tablet']),
            doseInstructionsJson: jsonEncode(<String>[
              'FAKE DATA - take one demo dose',
            ]),
            loadedAt: Value(seedTime),
            createdAt: seedTime,
          ),
        );
    await _database
        .into(_database.carouselStates)
        .insert(
          CarouselStatesCompanion.insert(
            profileId: profileId,
            activeLoadSessionId: const Value(loadSessionId),
            updatedAt: seedTime,
          ),
        );
  }
}
