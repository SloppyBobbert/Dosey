import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:flutter/material.dart';

class CarouselScreen extends StatefulWidget {
  const CarouselScreen({super.key});

  @override
  State<CarouselScreen> createState() => _CarouselScreenState();
}

class _CarouselScreenState extends State<CarouselScreen> {
  final _slotController = TextEditingController();

  @override
  void dispose() {
    _slotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);

    return StreamBuilder<List<Prescription>>(
      stream: dependencies.prescriptions.watchPrescriptions(),
      builder: (context, prescriptionSnapshot) {
        final prescriptions =
            prescriptionSnapshot.data ?? const <Prescription>[];
        final prescriptionsById = {
          for (final prescription in prescriptions)
            prescription.id: prescription,
        };

        return StreamBuilder<ScheduleProfile?>(
          stream: dependencies.scheduleProfiles.watchActiveProfile(),
          builder: (context, profileSnapshot) {
            final activeProfile = profileSnapshot.data;
            return StreamBuilder<List<ReminderSchedule>>(
              stream: _activeSchedulesStream(
                dependencies.reminders,
                activeProfile,
              ),
              builder: (context, scheduleSnapshot) {
                final schedules =
                    scheduleSnapshot.data ?? const <ReminderSchedule>[];
                return StreamBuilder<List<CarouselSlot>>(
                  stream: activeProfile == null
                      ? Stream<List<CarouselSlot>>.value(const <CarouselSlot>[])
                      : dependencies.carouselSlots.watchSlots(
                          profileId: activeProfile.id,
                        ),
                  builder: (context, slotSnapshot) {
                    final slots = slotSnapshot.data ?? const <CarouselSlot>[];
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      children: [
                        _CarouselHeader(slots: slots),
                        const SizedBox(height: 12),
                        const _PrototypeSafetyCard(),
                        const SizedBox(height: 12),
                        _AssignmentCard(
                          slotController: _slotController,
                          activeProfile: activeProfile,
                          schedules: schedules,
                          slots: slots,
                          prescriptionsById: prescriptionsById,
                        ),
                        const SizedBox(height: 12),
                        if (slots.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No slots assigned yet.'),
                            ),
                          )
                        else
                          for (final slot in slots)
                            _SlotCard(
                              slot: slot,
                              schedule: _scheduleForSlot(schedules, slot),
                              prescription:
                                  prescriptionsById[slot.prescriptionId],
                            ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static Stream<List<ReminderSchedule>> _activeSchedulesStream(
    ReminderRepository reminders,
    ScheduleProfile? activeProfile,
  ) {
    if (activeProfile == null) {
      return Stream<List<ReminderSchedule>>.value(const <ReminderSchedule>[]);
    }
    return reminders.watchSchedules(profileId: activeProfile.id);
  }

  static ReminderSchedule? _scheduleForSlot(
    List<ReminderSchedule> schedules,
    CarouselSlot slot,
  ) {
    for (final schedule in schedules) {
      if (schedule.id == slot.scheduleId) return schedule;
    }
    return null;
  }
}

class _CarouselHeader extends StatelessWidget {
  const _CarouselHeader({required this.slots});

  final List<CarouselSlot> slots;

  @override
  Widget build(BuildContext context) {
    final loaded = slots
        .where((slot) => slot.status == CarouselSlotStatus.loaded)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_carousel_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Daviky loading',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$loaded loaded / ${slots.length} assigned'),
            const SizedBox(height: 4),
            Text(
              'Loading only prepares compartments. Dosey still needs manual confirmation before a dose is marked taken.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeSafetyCard extends StatelessWidget {
  const _PrototypeSafetyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prototype loading safety',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Use candy, beads, dry beans, vitamins, or fake pills for prototype testing. Do not use real prescription medication in early tests.',
            ),
            const SizedBox(height: 6),
            Text(
              'Dosey does not verify pills, prescriptions, or swallowed doses.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.slotController,
    required this.activeProfile,
    required this.schedules,
    required this.slots,
    required this.prescriptionsById,
  });

  final TextEditingController slotController;
  final ScheduleProfile? activeProfile;
  final List<ReminderSchedule> schedules;
  final List<CarouselSlot> slots;
  final Map<String, Prescription> prescriptionsById;

  @override
  Widget build(BuildContext context) {
    final nextSchedule = _nextUnassignedSchedule();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assign slots',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            if (activeProfile != null)
              Text('Active schedule: ${activeProfile!.name}')
            else
              const Text('No active schedule profile.'),
            const SizedBox(height: 10),
            if (schedules.isEmpty)
              const Text('No active schedules to load.')
            else if (nextSchedule == null)
              const Text('All active schedules have a carousel slot.')
            else ...[
              Text(_scheduleLabel(nextSchedule)),
              const SizedBox(height: 10),
              TextFormField(
                controller: slotController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Slot number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: activeProfile == null
                    ? null
                    : () => _assignNextDose(context, nextSchedule),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Assign next dose'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ReminderSchedule? _nextUnassignedSchedule() {
    final assignedScheduleIds = {for (final slot in slots) slot.scheduleId};
    for (final schedule in schedules) {
      if (schedule.prescriptionId != null &&
          !assignedScheduleIds.contains(schedule.id)) {
        return schedule;
      }
    }
    return null;
  }

  String _scheduleLabel(ReminderSchedule schedule) {
    final prescription = prescriptionsById[schedule.prescriptionId];
    final label = prescription?.name ?? schedule.label;
    return '${schedule.timeLabel} · $label';
  }

  Future<void> _assignNextDose(
    BuildContext context,
    ReminderSchedule schedule,
  ) async {
    final slotNumber = int.tryParse(slotController.text.trim());
    if (slotNumber == null) {
      _showMessage(context, 'Enter a slot number.');
      return;
    }
    final prescriptionId = schedule.prescriptionId;
    final profile = activeProfile;
    if (prescriptionId == null || profile == null) {
      _showMessage(context, 'Choose a scheduled prescription first.');
      return;
    }

    final now = DateTime.now().toUtc();
    try {
      await DoseyAppScope.of(context).carouselSlots.assignSlot(
        CarouselSlot(
          id: '${profile.id}-${schedule.id}',
          slotNumber: slotNumber,
          prescriptionId: prescriptionId,
          scheduleId: schedule.id,
          profileId: profile.id,
          status: CarouselSlotStatus.assigned,
          createdAt: now,
          updatedAt: now,
        ),
      );
      slotController.clear();
      if (!context.mounted) return;
      _showMessage(context, 'Slot assigned.');
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      _showMessage(context, error.message.toString());
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.schedule,
    required this.prescription,
  });

  final CarouselSlot slot;
  final ReminderSchedule? schedule;
  final Prescription? prescription;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(slot.slotNumber.toString())),
        title: Text('Slot ${slot.slotNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(_doseLabel), Text(slot.status.label)],
        ),
        trailing: slot.status == CarouselSlotStatus.assigned
            ? TextButton(
                onPressed: () => _markLoaded(context),
                child: const Text('Mark loaded'),
              )
            : null,
      ),
    );
  }

  String get _doseLabel {
    final schedule = this.schedule;
    final name = prescription?.name ?? schedule?.label ?? slot.prescriptionId;
    return schedule == null ? name : '${schedule.timeLabel} · $name';
  }

  Future<void> _markLoaded(BuildContext context) async {
    try {
      await DoseyAppScope.of(context).carouselSlots.markLoaded(slot.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Slot marked loaded.')));
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }
}
