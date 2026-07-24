import 'package:dosey_app/core/carousel/carousel_load_session.dart';
import 'package:dosey_app/core/carousel/local_guided_carousel_load_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class GuidedDispenseTarget {
  const GuidedDispenseTarget({
    required this.profileId,
    required this.sessionId,
    required this.slotNumber,
    required this.slotStatus,
  });

  final String profileId;
  final String sessionId;
  final int slotNumber;
  final CarouselLoadSlotStatus slotStatus;

  bool get isReadyToDispense =>
      slotStatus == CarouselLoadSlotStatus.loaded ||
      slotStatus == CarouselLoadSlotStatus.retained;

  bool get canResolveAfterMovement =>
      slotStatus == CarouselLoadSlotStatus.dispensed;
}

Future<GuidedDispenseTarget?> resolveGuidedDispenseTarget({
  required DoseyDatabase database,
  required LocalGuidedCarouselLoadRepository guidedCarouselLoads,
  required String scheduleId,
  required String doseId,
}) async {
  final schedule =
      await ((database.select(database.reminderSchedules)
            ..where((row) => row.id.equals(scheduleId))
            ..limit(1))
          .getSingleOrNull());
  if (schedule == null || schedule.profileId.isEmpty) {
    return null;
  }
  final activeLoad = await guidedCarouselLoads.readActiveLoad(
    schedule.profileId,
  );
  if (activeLoad == null) {
    return null;
  }
  if (activeLoad.status == CarouselLoadSessionStatus.stale) {
    throw StateError('Active guided load is stale and cannot dispense.');
  }
  final matchingSlot = activeLoad.slots.where(
    (slot) =>
        slot.scheduleIds.contains(scheduleId) &&
        matchesGuidedDoseOccurrence(slot, doseId),
  );
  if (matchingSlot.isEmpty) {
    return null;
  }
  final slot = matchingSlot.first;
  return GuidedDispenseTarget(
    profileId: schedule.profileId,
    sessionId: activeLoad.id,
    slotNumber: slot.slotNumber,
    slotStatus: slot.status,
  );
}

bool matchesGuidedDoseOccurrence(CarouselLoadSlotSnapshot slot, String doseId) {
  final scheduledAt = slot.scheduledAt;
  if (scheduledAt == null) {
    return true;
  }
  final separatorIndex = doseId.lastIndexOf(':');
  if (separatorIndex <= 0 || separatorIndex >= doseId.length - 1) {
    return true;
  }
  final occurrenceDate = doseId.substring(separatorIndex + 1);
  final slotDate = scheduledAt.toLocal().toIso8601String().split('T').first;
  return occurrenceDate == slotDate;
}
