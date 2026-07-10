import 'dart:async';

import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_policy.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';
import 'package:drift/drift.dart';

class MissedDoseReconciliationService {
  MissedDoseReconciliationService({
    required this.reminders,
    required this.doseLog,
    this.carouselSlots,
    this.database,
    DateTime Function()? now,
    this.gracePeriod = const Duration(hours: 2),
  }) : _now = now ?? DateTime.now;

  final ReminderRepository reminders;
  final DoseLogRepository doseLog;
  final CarouselSlotRepository? carouselSlots;
  final DoseyDatabase? database;
  final DateTime Function() _now;
  final Duration gracePeriod;
  Future<void>? _reconcileInFlight;

  Future<void> reconcile() async {
    final existingRun = _reconcileInFlight;
    if (existingRun != null) {
      return existingRun;
    }
    final run = _reconcileOnce();
    _reconcileInFlight = run;
    try {
      await run;
    } finally {
      if (identical(_reconcileInFlight, run)) {
        _reconcileInFlight = null;
      }
    }
  }

  Future<void> _reconcileOnce() async {
    final now = _now();
    final schedules = await reminders.watchSchedules().first;
    final events = await doseLog.watchEvents().first;
    final datesToCheck = <DateTime>[
      DateTime(now.year, now.month, now.day - 1),
      DateTime(now.year, now.month, now.day),
    ];

    for (final date in datesToCheck) {
      for (final schedule in schedules) {
        final candidate = MissedDosePolicy.overdueDoseForDate(
          schedule,
          events,
          date: date,
          now: now,
          gracePeriod: gracePeriod,
        );
        if (candidate == null) {
          continue;
        }
        try {
          await _persistMissedDose(candidate);
        } on Object {
          // Keep reconciliation best-effort per dose so one bad write does not
          // starve later overdue doses on the same startup or timer tick.
        }
      }
    }
  }

  Future<void> _persistMissedDose(MissedDoseCandidate candidate) async {
    final currentDatabase = database;
    if (currentDatabase == null) {
      await doseLog.addEvent(candidate.event);
      return;
    }

    await currentDatabase.transaction(() async {
      if (await _hasPersistedTerminalEventForDose(
        currentDatabase,
        candidate.doseId,
      )) {
        return;
      }
      await _retireLoadedSlot(candidate);
      await doseLog.addEvent(candidate.event);
    });
  }

  Future<void> _retireLoadedSlot(MissedDoseCandidate candidate) async {
    final currentDatabase = database;
    final currentCarouselSlots = carouselSlots;
    if (currentDatabase == null || currentCarouselSlots == null) {
      return;
    }
    final slot =
        await (currentDatabase.select(currentDatabase.carouselSlots)
              ..where(
                (row) =>
                    row.scheduleId.equals(
                      _scheduleIdFromDoseId(candidate.doseId),
                    ) &
                    row.status.isIn(<String>[
                      CarouselSlotStatus.loaded.storageValue,
                      CarouselSlotStatus.dispensed.storageValue,
                    ]),
              )
              ..limit(1))
            .getSingleOrNull();
    if (slot == null) {
      return;
    }
    await currentCarouselSlots.markNeedsReview(slot.id);
  }

  static Future<bool> _hasPersistedTerminalEventForDose(
    DoseyDatabase database,
    String doseId,
  ) async {
    final existingEvent =
        await (database.select(database.doseLogEvents)
              ..where(
                (row) =>
                    row.doseId.equals(doseId) &
                    row.kind.isIn(
                      TodayNextDoseHelper.terminalDoseEventKindNames,
                    ),
              )
              ..limit(1))
            .getSingleOrNull();
    return existingEvent != null;
  }

  static String _scheduleIdFromDoseId(String doseId) {
    final separatorIndex = doseId.lastIndexOf(':');
    return separatorIndex > 0 ? doseId.substring(0, separatorIndex) : doseId;
  }
}
