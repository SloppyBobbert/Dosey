import 'package:dosey_app/core/logging/phone_dose_action_service.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_occurrence_resolver.dart';

class PhoneOnlyMissedDoseReconciliationService implements MissedDoseReconciler {
  PhoneOnlyMissedDoseReconciliationService({
    required this.reminders,
    required this.actions,
    required this.deviceId,
    required this.timezoneId,
    required this.now,
    this.gracePeriod = const Duration(hours: 2),
  });

  final ReminderRepository reminders;
  final PhoneDoseActionService actions;
  final Future<String> Function() deviceId;
  final Future<String> Function() timezoneId;
  final DateTime Function() now;
  final Duration gracePeriod;
  Future<void>? _inFlight;

  @override
  Future<void> reconcile() async {
    final existing = _inFlight;
    if (existing != null) return existing;
    final run = _reconcileOnce();
    _inFlight = run;
    try {
      await run;
    } finally {
      if (identical(_inFlight, run)) _inFlight = null;
    }
  }

  Future<void> _reconcileOnce() async {
    final now = this.now().toUtc();
    final schedules = await reminders.watchSchedules().first;
    final resolvedDeviceId = await deviceId();
    final resolvedTimezoneId = await timezoneId();
    const resolver = ReminderOccurrenceResolver();
    final localToday = resolver.localDateFor(now, resolvedTimezoneId);
    for (final dayOffset in const [-1, 0]) {
      final date = DateTime.utc(
        localToday.year,
        localToday.month,
        localToday.day + dayOffset,
      );
      for (final schedule in schedules.where((row) => row.isEnabled)) {
        final occurrence = resolver.resolve(
          schedule: schedule,
          localDate: date,
          timezoneId: resolvedTimezoneId,
        );
        if (occurrence.scheduledAt.add(gracePeriod).isAfter(now)) continue;
        await actions.recordMissedIfNoTerminal(
          PhoneDoseActionRequest(
            occurrence: occurrence,
            medicationId: schedule.prescriptionId ?? schedule.id,
            kind: PhoneDoseActionKind.missed,
            occurredAt: now,
            deviceId: resolvedDeviceId,
          ),
        );
      }
    }
  }
}
