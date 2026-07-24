import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/features/doses/dose_action_service.dart';
import 'package:flutter/material.dart';

class DoseActionLogger {
  const DoseActionLogger._();

  // Returns an inventory id only when the current schedule still points at a
  // known prescription, so refill counts never move for stale schedule data.
  static String? inventoryPrescriptionIdFor(
    ReminderSchedule? schedule,
    Iterable<String> prescriptionIds,
  ) {
    if (schedule == null ||
        !prescriptionIds.contains(schedule.prescriptionId)) {
      return null;
    }
    return schedule.prescriptionId;
  }

  static Future<bool> logDoseAction(
    BuildContext context,
    DoseLogEvent event,
    String successMessage, {
    CarouselSlot? retireLoadedSlot,
    String? inventoryPrescriptionId,
  }) async {
    try {
      final dependencies = DoseyAppScope.of(context);
      final result =
          await DoseActionService(
            database: dependencies.database,
            carouselSlots: dependencies.carouselSlots,
            guidedCarouselLoads: dependencies.guidedCarouselLoads,
            prescriptions: dependencies.prescriptions,
            doseLog: dependencies.doseLog,
          ).record(
            event,
            retireLoadedSlot: retireLoadedSlot,
            inventoryPrescriptionId: inventoryPrescriptionId,
          );
      if (!context.mounted) {
        return true;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      if (result == DoseActionResult.ignored) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Dose already logged for today.')),
        );
        return true;
      }
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      return true;
    } on Object catch (error) {
      if (!context.mounted) {
        return false;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text('Dose action failed: $error')),
      );
      return false;
    }
  }
}
