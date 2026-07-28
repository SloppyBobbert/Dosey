import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/eligible_carousel_slots.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/active_profile_schedules_stream.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:flutter/material.dart';

class MedicationsHubScreen extends StatelessWidget {
  const MedicationsHubScreen({
    super.key,
    required this.onOpenSchedules,
    required this.onOpenPrescriptions,
    required this.onManageCarousel,
  });

  final VoidCallback onOpenSchedules;
  final VoidCallback onOpenPrescriptions;
  final VoidCallback onManageCarousel;

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    return StreamBuilder<List<Prescription>>(
      stream: dependencies.prescriptions.watchPrescriptions(),
      builder: (context, prescriptionSnapshot) {
        final prescriptionsById = {
          for (final prescription
              in prescriptionSnapshot.data ?? const <Prescription>[])
            prescription.id: prescription,
        };
        return StreamBuilder<ScheduleProfile?>(
          stream: dependencies.scheduleProfiles.watchActiveProfile(),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data;
            return StreamBuilder<List<ReminderSchedule>>(
              stream: watchActiveProfileSchedules(
                dependencies.reminders,
                profile,
              ),
              builder: (context, scheduleSnapshot) {
                final schedules =
                    scheduleSnapshot.data ?? const <ReminderSchedule>[];
                return StreamBuilder<List<CarouselSlot>>(
                  stream: profile == null
                      ? Stream.value(const <CarouselSlot>[])
                      : dependencies.carouselSlots.watchSlots(
                          profileId: profile.id,
                        ),
                  builder: (context, slotSnapshot) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    children: [
                      _MedicationSummary(
                        schedules: schedules,
                        prescriptionsById: prescriptionsById,
                        onOpenSchedules: onOpenSchedules,
                      ),
                      const SizedBox(height: 20),
                      _CarouselReadiness(
                        slots: slotSnapshot.data ?? const <CarouselSlot>[],
                        activeProfileId: profile?.id,
                        schedules: schedules,
                        onManage: onManageCarousel,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'More options',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.alarm_outlined),
                              title: const Text('Schedules'),
                              subtitle: const Text('Change medication times'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: onOpenSchedules,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.medication_outlined),
                              title: const Text('Prescriptions'),
                              subtitle: const Text('Add or update medications'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: onOpenPrescriptions,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MedicationSummary extends StatelessWidget {
  const _MedicationSummary({
    required this.schedules,
    required this.prescriptionsById,
    required this.onOpenSchedules,
  });

  final List<ReminderSchedule> schedules;
  final Map<String, Prescription> prescriptionsById;
  final VoidCallback onOpenSchedules;

  @override
  Widget build(BuildContext context) {
    final upcoming = schedules.where((schedule) => schedule.isEnabled).toList()
      ..sort((a, b) => a.timeLabel.compareTo(b.timeLabel));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your medications', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          upcoming.isEmpty
              ? schedules.isEmpty
                    ? 'Add a schedule when you are ready.'
                    : 'Medication times are paused.'
              : 'Your next scheduled medication times.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                schedules.isEmpty
                    ? 'No medication times set yet.'
                    : 'No medication times are active.',
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < upcoming.length && index < 4;
                  index++
                ) ...[
                  ListTile(
                    title: Text(
                      prescriptionsById[upcoming[index].prescriptionId]?.name ??
                          upcoming[index].label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: const Text('Scheduled medication'),
                    trailing: Text(
                      upcoming[index].timeLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (index + 1 < upcoming.length && index < 3)
                    const Divider(height: 1),
                ],
                if (upcoming.length > 4) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: Text(
                      '${upcoming.length - 4} more medication time${upcoming.length - 4 == 1 ? '' : 's'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onOpenSchedules,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CarouselReadiness extends StatelessWidget {
  const _CarouselReadiness({
    required this.slots,
    required this.activeProfileId,
    required this.schedules,
    required this.onManage,
  });

  final List<CarouselSlot> slots;
  final String? activeProfileId;
  final List<ReminderSchedule> schedules;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final eligibleSlots = eligibleCarouselSlots(
      slots: slots,
      activeProfileId: activeProfileId,
      schedules: schedules,
    );
    final reviews = eligibleSlots
        .where((slot) => slot.status == CarouselSlotStatus.needsReview)
        .length;
    final ready = eligibleSlots
        .where((slot) => slot.status == CarouselSlotStatus.loaded)
        .length;
    final message = reviews > 0
        ? '$reviews slot${reviews == 1 ? '' : 's'} need review.'
        : ready > 0
        ? '$ready slot${ready == 1 ? '' : 's'} ready.'
        : eligibleSlots.isEmpty
        ? 'No slots set up yet.'
        : '${eligibleSlots.length} slot${eligibleSlots.length == 1 ? '' : 's'} assigned.';
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: reviews > 0
          ? scheme.errorContainer.withValues(alpha: 0.5)
          : scheme.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              reviews > 0
                  ? Icons.warning_amber_rounded
                  : Icons.view_carousel_outlined,
              color: reviews > 0 ? scheme.error : scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carousel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(message),
                ],
              ),
            ),
            TextButton(
              onPressed: onManage,
              child: const Text('Manage carousel'),
            ),
          ],
        ),
      ),
    );
  }
}
