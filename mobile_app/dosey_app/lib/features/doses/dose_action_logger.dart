import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';
import 'package:drift/drift.dart' hide Column;
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
      // Robot Face may only know the dose id; fill in the slot and inventory
      // context so every surface gets the same transactional side effects.
      final resolvedContext =
          retireLoadedSlot == null || inventoryPrescriptionId == null
          ? await _resolveDoseContext(dependencies, event)
          : null;
      final effectiveLoadedSlot =
          retireLoadedSlot ?? resolvedContext?.loadedSlot;
      final effectiveInventoryPrescriptionId =
          inventoryPrescriptionId ?? resolvedContext?.inventoryPrescriptionId;
      final retiresLoadedSlot =
          effectiveLoadedSlot != null && _isTerminalDoseEvent(event);
      final recordsInventory =
          event.marksDoseTaken && effectiveInventoryPrescriptionId != null;
      var ignoredDoseAction = false;
      await dependencies.database.transaction(() async {
        if (await _shouldIgnorePostTerminalAuditEvent(
          dependencies.database,
          event,
        )) {
          ignoredDoseAction = true;
          return;
        }
        // Terminal outcomes are one-shot per dose. Keep stale surfaces from
        // double-retiring slots or double-decrementing refills.
        if (!_canPersistAfterTerminal(event) &&
            await _hasPersistedTerminalEventForDose(
              dependencies.database,
              event.doseId,
            )) {
          ignoredDoseAction = true;
          return;
        }
        if (retiresLoadedSlot) {
          final loadedSlot = effectiveLoadedSlot;
          await dependencies.carouselSlots.markNeedsReview(loadedSlot.id);
        }
        if (recordsInventory) {
          final inventoryPrescriptionId = effectiveInventoryPrescriptionId;
          await dependencies.prescriptions.recordTakenDose(
            inventoryPrescriptionId,
            occurredAt: event.occurredAt,
          );
        }
        await dependencies.doseLog.addEvent(event);
      });
      if (!context.mounted) {
        return true;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      if (ignoredDoseAction) {
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

  static bool _isTerminalDoseEvent(DoseLogEvent event) {
    return TodayNextDoseHelper.isTerminalDoseEventKind(event.kind);
  }

  static bool _canPersistAfterTerminal(DoseLogEvent event) {
    return event.kind == DoseLogEventKind.doseMissedRecognized;
  }

  static Future<bool> _shouldIgnorePostTerminalAuditEvent(
    DoseyDatabase database,
    DoseLogEvent event,
  ) async {
    if (!_canPersistAfterTerminal(event)) {
      return false;
    }

    final hasMissedEvent = await _hasPersistedEventKindForDose(
      database,
      event.doseId,
      DoseLogEventKind.doseMissed.name,
    );
    if (!hasMissedEvent) {
      return true;
    }

    return _hasPersistedEventKindForDose(
      database,
      event.doseId,
      DoseLogEventKind.doseMissedRecognized.name,
    );
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

  static Future<bool> _hasPersistedEventKindForDose(
    DoseyDatabase database,
    String doseId,
    String kind,
  ) async {
    final existingEvent =
        await (database.select(database.doseLogEvents)
              ..where(
                (row) => row.doseId.equals(doseId) & row.kind.equals(kind),
              )
              ..limit(1))
            .getSingleOrNull();
    return existingEvent != null;
  }

  static Future<_ResolvedDoseActionContext?> _resolveDoseContext(
    DoseyAppDependencies dependencies,
    DoseLogEvent event,
  ) async {
    final scheduleId = _scheduleIdFromDoseId(event.doseId);
    if (scheduleId == null) {
      return null;
    }
    final schedule = await (dependencies.database.select(
      dependencies.database.reminderSchedules,
    )..where((row) => row.id.equals(scheduleId))).getSingleOrNull();
    if (schedule == null) {
      return null;
    }
    // After a controller dispense the slot may already be `dispensed`; both
    // `loaded` and `dispensed` slots should move to needs-review on resolution.
    final loadedSlot =
        await (dependencies.database.select(dependencies.database.carouselSlots)
              ..where(
                (row) =>
                    row.scheduleId.equals(scheduleId) &
                    row.status.isIn(<String>[
                      CarouselSlotStatus.loaded.storageValue,
                      CarouselSlotStatus.dispensed.storageValue,
                    ]),
              )
              ..limit(1))
            .getSingleOrNull();
    final prescriptionId = schedule.prescriptionId;
    // Schedule links can outlive local prescription rows during edits/imports;
    // verify the row before recording refill usage.
    final prescriptionExists = prescriptionId != null
        ? await (dependencies.database.select(
                      dependencies.database.prescriptions,
                    )
                    ..where((row) => row.id.equals(prescriptionId))
                    ..limit(1))
                  .getSingleOrNull() !=
              null
        : false;
    return _ResolvedDoseActionContext(
      loadedSlot: loadedSlot == null
          ? null
          : CarouselSlot(
              id: loadedSlot.id,
              slotNumber: loadedSlot.slotNumber,
              prescriptionId: loadedSlot.prescriptionId,
              scheduleId: loadedSlot.scheduleId,
              profileId: loadedSlot.profileId,
              status: CarouselSlotStatus.fromStorageValue(loadedSlot.status),
              createdAt: loadedSlot.createdAt.toUtc(),
              updatedAt: loadedSlot.updatedAt.toUtc(),
            ),
      inventoryPrescriptionId: prescriptionExists ? prescriptionId : null,
    );
  }

  static String? _scheduleIdFromDoseId(String doseId) {
    final separatorIndex = doseId.lastIndexOf(':');
    if (separatorIndex <= 0) {
      return null;
    }
    return doseId.substring(0, separatorIndex);
  }
}

class _ResolvedDoseActionContext {
  const _ResolvedDoseActionContext({
    required this.loadedSlot,
    required this.inventoryPrescriptionId,
  });

  final CarouselSlot? loadedSlot;
  final String? inventoryPrescriptionId;
}
