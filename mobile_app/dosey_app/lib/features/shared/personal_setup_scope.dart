import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/admin/protected_admin_action.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/notifications/reminder_scheduler.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule_service.dart';
import 'package:dosey_app/core/schedules/local_schedule_profile_repository.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/action_pin_gate.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter/widgets.dart';

/// Only the stores and guard used by the existing medication setup widgets.
class PersonalSetupDependencies {
  PersonalSetupDependencies({
    required this.database,
    required this.prescriptions,
    required this.reminders,
    required this.scheduleProfiles,
    required this.reminderSchedules,
    required this.runner,
    required this.sourceRole,
    this.localWeb = false,
  });

  factory PersonalSetupDependencies.local(DoseyDatabase database) {
    final reminders = LocalReminderRepository(
      database,
      requireExistingLinks: true,
    );
    return PersonalSetupDependencies(
      database: database,
      prescriptions: LocalPrescriptionRepository(database),
      reminders: reminders,
      scheduleProfiles: LocalScheduleProfileRepository(database),
      reminderSchedules: ReminderScheduleService(
        repository: reminders,
        scheduler: const ForegroundOnlyReminderScheduler(),
      ),
      runner: ProtectedAdminActionRunner(
        pinGate: ActionPinGate(
          LocalAppSettingsRepository(
            database,
            defaultRole: AppDeviceRole.webPersonal,
          ),
        ),
        localAuth: LocalAuthRepository(database),
      ),
      sourceRole: () async => AppDeviceRole.webPersonal.storageValue,
      localWeb: true,
    );
  }

  final DoseyDatabase database;
  final PrescriptionRepository prescriptions;
  final ReminderRepository reminders;
  final ScheduleProfileRepository scheduleProfiles;
  final ReminderScheduleService reminderSchedules;
  final ProtectedAdminActionRunner runner;
  final Future<String> Function() sourceRole;
  final bool localWeb;
  Future<void>? _pending;
  bool _stopped = false;

  Future<void> initializeLocalProfile() => database.transaction(() async {
    // Serialize first-open tabs before deciding whether a profile is missing.
    await database.customUpdate('UPDATE schedule_profiles SET id = id');
    final profiles = await database.select(database.scheduleProfiles).get();
    if (profiles.any((profile) => profile.isActive)) return;
    if (profiles.isEmpty) {
      final now = DateTime.now().toUtc();
      await scheduleProfiles.upsertProfile(
        ScheduleProfile(
          id: ScheduleProfile.defaultProfileId,
          name: 'Personal schedule',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await scheduleProfiles.setActiveProfile(profiles.first.id);
    }
  });

  Future<ProtectedAdminActionResult<T>> run<T>({
    required ProtectedAdminPinRequest requestPin,
    required ProtectedAdminAction<T> action,
  }) async {
    if (_stopped || _pending != null) {
      return const ProtectedAdminActionResult.cancelled();
    }
    final future = runner.run<T>(requestPin: requestPin, action: action);
    _pending = future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      return await future;
    } finally {
      _pending = null;
    }
  }

  Future<void> drain() async {
    _stopped = true;
    await _pending;
  }
}

class PersonalSetupScope extends InheritedWidget {
  const PersonalSetupScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  /// Absent until local storage and profile initialization are ready.
  final PersonalSetupDependencies? dependencies;
  static PersonalSetupDependencies? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PersonalSetupScope>()
      ?.dependencies;
  static PersonalSetupDependencies of(BuildContext context) {
    final local = maybeOf(context);
    if (local != null) return local;
    final native = DoseyAppScope.of(context);
    return PersonalSetupDependencies(
      database: native.database,
      prescriptions: native.prescriptions,
      reminders: native.reminders,
      scheduleProfiles: native.scheduleProfiles,
      reminderSchedules: native.reminderSchedules,
      runner: ProtectedAdminActionRunner(
        pinGate: native.actionPinGate,
        localAuth: native.localAuth,
      ),
      sourceRole: () async =>
          (await native.effectiveRole.getDeviceRole()).storageValue,
    );
  }

  @override
  bool updateShouldNotify(PersonalSetupScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}

/// Persists schedules for foreground use only. Never calls an OS notification API.
class ForegroundOnlyReminderScheduler implements ReminderScheduler {
  const ForegroundOnlyReminderScheduler();
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> cancelDoseReminder(String doseId) async {}
  @override
  Future<void> scheduleDoseReminder({
    required String doseId,
    required DateTime scheduledFor,
    required String label,
    required bool repeatsDaily,
  }) async {
    if (!repeatsDaily) {
      throw UnsupportedError('Web OS reminders are not supported.');
    }
  }
}
