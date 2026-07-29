import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';

List<CarouselSlot> eligibleCarouselSlots({
  required Iterable<CarouselSlot> slots,
  required String? activeProfileId,
  required Iterable<ReminderSchedule> schedules,
}) {
  if (activeProfileId == null) {
    return const [];
  }

  final enabledScheduleIds = {
    for (final schedule in schedules)
      if (schedule.isEnabled && schedule.profileId == activeProfileId)
        schedule.id,
  };
  return slots
      .where(
        (slot) =>
            slot.profileId == activeProfileId &&
            enabledScheduleIds.contains(slot.scheduleId),
      )
      .toList();
}
