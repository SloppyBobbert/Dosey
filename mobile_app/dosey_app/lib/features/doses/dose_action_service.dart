import 'package:dosey_app/core/carousel/carousel_load_session.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/guided_dispense_target_resolver.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';
import 'package:drift/drift.dart';

enum DoseActionResult { recorded, ignored }

class DoseActionService {
  const DoseActionService({
    required this.database,
    required this.carouselSlots,
    required this.guidedCarouselLoads,
    required this.prescriptions,
    required this.doseLog,
  });

  final DoseyDatabase database;
  final CarouselSlotRepository carouselSlots;
  final LocalGuidedCarouselLoadRepository guidedCarouselLoads;
  final PrescriptionRepository prescriptions;
  final DoseLogRepository doseLog;

  Future<DoseActionResult> record(
    DoseLogEvent event, {
    CarouselSlot? retireLoadedSlot,
    String? inventoryPrescriptionId,
  }) async {
    final resolvedContext = await _resolveDoseContext(event);
    final effectiveLoadedSlot = retireLoadedSlot ?? resolvedContext?.loadedSlot;
    final effectiveInventoryPrescriptionId =
        inventoryPrescriptionId ?? resolvedContext?.inventoryPrescriptionId;
    final effectiveGuidedDispenseContext =
        resolvedContext?.guidedDispenseContext;
    final retiresLoadedSlot =
        effectiveLoadedSlot != null && _isTerminalDoseEvent(event);
    final recordsInventory =
        event.marksDoseTaken && effectiveInventoryPrescriptionId != null;
    var result = DoseActionResult.recorded;

    await database.transaction(() async {
      if (await _shouldIgnorePostTerminalAuditEvent(event) ||
          (!_canPersistAfterTerminal(event) &&
              await _hasPersistedTerminalEventForDose(event.doseId))) {
        result = DoseActionResult.ignored;
        return;
      }
      if (effectiveGuidedDispenseContext != null &&
          event.marksDoseTaken &&
          !effectiveGuidedDispenseContext.canResolveAfterMovement) {
        throw StateError(
          'Confirm controller movement before logging a taken dose outcome.',
        );
      }
      if (effectiveGuidedDispenseContext != null &&
          _isTerminalDoseEvent(event) &&
          !event.marksDoseTaken) {
        if (effectiveGuidedDispenseContext.canResolveAfterMovement) {
          await guidedCarouselLoads.confirmDispensedSlotNeedsReview(
            profileId: effectiveGuidedDispenseContext.profileId,
            activeSessionId: effectiveGuidedDispenseContext.sessionId,
            slotNumber: effectiveGuidedDispenseContext.slotNumber,
            occurredAt: event.occurredAt,
            reason: event.kind.name,
          );
        } else {
          await guidedCarouselLoads.quarantineSlotForReview(
            profileId: effectiveGuidedDispenseContext.profileId,
            activeSessionId: effectiveGuidedDispenseContext.sessionId,
            slotNumber: effectiveGuidedDispenseContext.slotNumber,
            occurredAt: event.occurredAt,
            reason: event.kind.name,
          );
        }
      }
      if (retiresLoadedSlot && effectiveGuidedDispenseContext == null) {
        await carouselSlots.markNeedsReview(effectiveLoadedSlot.id);
      }
      if (recordsInventory) {
        if (effectiveGuidedDispenseContext != null) {
          await guidedCarouselLoads.confirmDispensedSlotTaken(
            profileId: effectiveGuidedDispenseContext.profileId,
            activeSessionId: effectiveGuidedDispenseContext.sessionId,
            slotNumber: effectiveGuidedDispenseContext.slotNumber,
            occurredAt: event.occurredAt,
          );
        } else {
          await prescriptions.recordTakenDose(
            effectiveInventoryPrescriptionId,
            occurredAt: event.occurredAt,
          );
        }
      }
      await doseLog.addEvent(event);
    });
    return result;
  }

  static bool _isTerminalDoseEvent(DoseLogEvent event) =>
      TodayNextDoseHelper.isTerminalDoseEventKind(event.kind);

  static bool _canPersistAfterTerminal(DoseLogEvent event) =>
      event.kind == DoseLogEventKind.doseMissedRecognized;

  Future<bool> _shouldIgnorePostTerminalAuditEvent(DoseLogEvent event) async {
    if (!_canPersistAfterTerminal(event)) return false;
    if (!await _hasPersistedEventKindForDose(
      event.doseId,
      DoseLogEventKind.doseMissed.name,
    )) {
      return true;
    }
    return _hasPersistedEventKindForDose(
      event.doseId,
      DoseLogEventKind.doseMissedRecognized.name,
    );
  }

  Future<bool> _hasPersistedTerminalEventForDose(String doseId) async {
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

  Future<bool> _hasPersistedEventKindForDose(String doseId, String kind) async {
    final existingEvent =
        await (database.select(database.doseLogEvents)
              ..where(
                (row) => row.doseId.equals(doseId) & row.kind.equals(kind),
              )
              ..limit(1))
            .getSingleOrNull();
    return existingEvent != null;
  }

  Future<_ResolvedDoseActionContext?> _resolveDoseContext(
    DoseLogEvent event,
  ) async {
    final scheduleId = _scheduleIdFromDoseId(event.doseId);
    if (scheduleId == null) return null;
    final schedule = await (database.select(
      database.reminderSchedules,
    )..where((row) => row.id.equals(scheduleId))).getSingleOrNull();
    if (schedule == null) return null;
    final loadedSlot =
        await (database.select(database.carouselSlots)
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
    final prescriptionExists = prescriptionId != null
        ? await (database.select(database.prescriptions)
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
      guidedDispenseContext: schedule.profileId.isEmpty
          ? null
          : await _resolveGuidedDispenseContext(scheduleId, event.doseId),
    );
  }

  Future<_GuidedDispenseContext?> _resolveGuidedDispenseContext(
    String scheduleId,
    String doseId,
  ) async {
    final target = await resolveGuidedDispenseTarget(
      database: database,
      guidedCarouselLoads: guidedCarouselLoads,
      scheduleId: scheduleId,
      doseId: doseId,
    );
    if (target == null) return null;
    return _GuidedDispenseContext(
      profileId: target.profileId,
      sessionId: target.sessionId,
      slotNumber: target.slotNumber,
      slotStatus: target.slotStatus,
    );
  }

  static String? _scheduleIdFromDoseId(String doseId) {
    final separatorIndex = doseId.lastIndexOf(':');
    if (separatorIndex <= 0) return null;
    return doseId.substring(0, separatorIndex);
  }
}

class _ResolvedDoseActionContext {
  const _ResolvedDoseActionContext({
    required this.loadedSlot,
    required this.inventoryPrescriptionId,
    required this.guidedDispenseContext,
  });

  final CarouselSlot? loadedSlot;
  final String? inventoryPrescriptionId;
  final _GuidedDispenseContext? guidedDispenseContext;
}

class _GuidedDispenseContext {
  const _GuidedDispenseContext({
    required this.profileId,
    required this.sessionId,
    required this.slotNumber,
    required this.slotStatus,
  });

  final String profileId;
  final String sessionId;
  final int slotNumber;
  final CarouselLoadSlotStatus slotStatus;

  bool get canResolveAfterMovement =>
      slotStatus == CarouselLoadSlotStatus.dispensed;
}
