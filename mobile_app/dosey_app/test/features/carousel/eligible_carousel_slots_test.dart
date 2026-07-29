import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/eligible_carousel_slots.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const activeProfileId = 'active-profile';
  final now = DateTime.utc(2040);

  ReminderSchedule schedule({
    required String id,
    required String profileId,
    required bool isEnabled,
  }) => ReminderSchedule(
    id: id,
    label: id,
    profileId: profileId,
    hour: 8,
    minute: 0,
    isEnabled: isEnabled,
    createdAt: now,
    updatedAt: now,
  );

  CarouselSlot slot({
    required String id,
    required String profileId,
    required String scheduleId,
    CarouselSlotStatus status = CarouselSlotStatus.loaded,
  }) => CarouselSlot(
    id: id,
    slotNumber: 1,
    prescriptionId: 'prescription',
    scheduleId: scheduleId,
    profileId: profileId,
    status: status,
    createdAt: now,
    updatedAt: now,
  );

  test('keeps only slots for enabled schedules in the active profile', () {
    final slots = eligibleCarouselSlots(
      activeProfileId: activeProfileId,
      schedules: [
        schedule(id: 'enabled', profileId: activeProfileId, isEnabled: true),
        schedule(id: 'disabled', profileId: activeProfileId, isEnabled: false),
        schedule(
          id: 'other-profile',
          profileId: 'inactive-profile',
          isEnabled: true,
        ),
      ],
      slots: [
        slot(
          id: 'enabled-slot',
          profileId: activeProfileId,
          scheduleId: 'enabled',
        ),
        slot(
          id: 'disabled-slot',
          profileId: activeProfileId,
          scheduleId: 'disabled',
          status: CarouselSlotStatus.needsReview,
        ),
        slot(
          id: 'inactive-slot',
          profileId: 'inactive-profile',
          scheduleId: 'other-profile',
          status: CarouselSlotStatus.needsReview,
        ),
      ],
    );

    expect(slots.map((slot) => slot.id), ['enabled-slot']);
    expect(slots.single.status, CarouselSlotStatus.loaded);
  });

  test('returns no slots when there is no active profile', () {
    expect(
      eligibleCarouselSlots(
        activeProfileId: null,
        schedules: [
          schedule(id: 'enabled', profileId: activeProfileId, isEnabled: true),
        ],
        slots: [
          slot(
            id: 'enabled-slot',
            profileId: activeProfileId,
            scheduleId: 'enabled',
          ),
        ],
      ),
      isEmpty,
    );
  });
}
