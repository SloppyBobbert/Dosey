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

  static String doseIdForToday(String scheduleId) {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$scheduleId:${now.year}-$month-$day';
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
    final readyToDispense = loaded;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.onTertiaryContainer,
                  foregroundColor: colorScheme.tertiaryContainer,
                  child: const Icon(Icons.view_carousel_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loading bay',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Daviky carousel',
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Daviky loading',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$loaded loaded / ${slots.length} assigned',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Loading only prepares compartments. Dosey still needs manual confirmation before a dose is marked taken.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CarouselHeroChip(
                  icon: Icons.inventory_2_outlined,
                  label: '${slots.length} assigned',
                ),
                _CarouselHeroChip(
                  icon: Icons.check_circle_outline,
                  label: '$loaded loaded',
                ),
                _CarouselHeroChip(
                  icon: Icons.play_circle_outline,
                  label: '$readyToDispense ready to dispense',
                ),
                const _CarouselHeroChip(
                  icon: Icons.route_outlined,
                  label: 'Feeds dispense flow',
                ),
                const _CarouselHeroChip(
                  icon: Icons.science_outlined,
                  label: 'Prototype loading',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselHeroChip extends StatelessWidget {
  const _CarouselHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.onTertiaryContainer.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onTertiaryContainer),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
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
        trailing: _SlotAction(
          status: slot.status,
          onMarkLoaded: () => _markLoaded(context),
          onDispense: () => _dispense(context),
        ),
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

  Future<void> _dispense(BuildContext context) async {
    try {
      final dependencies = DoseyAppScope.of(context);
      await dependencies.controller.requestDispense(
        doseId: _CarouselScreenState.doseIdForToday(slot.scheduleId),
      );
      await dependencies.carouselSlots.markDispensed(slot.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dispense command logged. Confirm taken only after the dose is verified.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dispense failed: $error')));
    }
  }
}

class _SlotAction extends StatelessWidget {
  const _SlotAction({
    required this.status,
    required this.onMarkLoaded,
    required this.onDispense,
  });

  final CarouselSlotStatus status;
  final VoidCallback onMarkLoaded;
  final VoidCallback onDispense;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      CarouselSlotStatus.assigned => TextButton(
        onPressed: onMarkLoaded,
        child: const Text('Mark loaded'),
      ),
      CarouselSlotStatus.loaded => TextButton(
        onPressed: onDispense,
        child: const Text('Dispense slot'),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
