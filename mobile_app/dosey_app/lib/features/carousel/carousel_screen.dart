import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/carousel/carousel_dispense_coordinator.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
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
                    final slotRows =
                        slotSnapshot.data ?? const <CarouselSlot>[];
                    final scheduleIds = {
                      for (final schedule in schedules)
                        if (schedule.isEnabled) schedule.id,
                    };
                    final slots = slotRows
                        .where((slot) => scheduleIds.contains(slot.scheduleId))
                        .toList();
                    // Hide slots for disabled or inactive-profile schedules so
                    // this screen matches what Today can actually dispense.
                    return StreamBuilder<AppDeviceRole>(
                      stream: dependencies.settings.watchDeviceRole(),
                      builder: (context, roleSnapshot) {
                        return StreamBuilder<ControllerSnapshot>(
                          stream: dependencies.controller.watchController(),
                          builder: (context, controllerSnapshot) {
                            final controller =
                                controllerSnapshot.data ??
                                const ControllerSnapshot.disconnected();
                            final canRequestDispense = _canRequestDispense(
                              roleSnapshot.data,
                              controller,
                            );
                            return ListView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                18,
                                16,
                                24,
                              ),
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
                                _RefillCountdownCard(slots: slots),
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
                                      schedule: _scheduleForSlot(
                                        schedules,
                                        slot,
                                      ),
                                      prescription:
                                          prescriptionsById[slot
                                              .prescriptionId],
                                      canRequestDispense: canRequestDispense,
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

  static bool _canRequestDispense(
    AppDeviceRole? storedRole,
    ControllerSnapshot controller,
  ) {
    final platform = currentAppDevicePlatform();
    final role = storedRole != null && storedRole.isAllowedOn(platform)
        ? storedRole
        : AppDeviceRole.defaultFor(platform);
    return role.canHostRobot && controller.canRequestDispense;
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

class _RefillCountdownCard extends StatelessWidget {
  const _RefillCountdownCard({required this.slots});

  final List<CarouselSlot> slots;

  @override
  Widget build(BuildContext context) {
    final remaining = slots
        .where(
          (slot) =>
              slot.status == CarouselSlotStatus.assigned ||
              slot.status == CarouselSlotStatus.loaded,
        )
        .length;
    final dispensed = slots
        .where((slot) => slot.status == CarouselSlotStatus.dispensed)
        .toList();
    final needsReview = slots
        .where((slot) => slot.status == CarouselSlotStatus.needsReview)
        .length;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final warning = _warningFor(remaining, slots.isEmpty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.inventory_2_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refill countdown',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _doseCountLabel(remaining),
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dosey counts assigned or loaded slots as remaining. Dispensed slots need refill review before reuse.',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RefillStatusChip(
                  icon: warning.icon,
                  label: warning.label,
                  isWarning: warning.isWarning,
                ),
                _RefillStatusChip(
                  icon: Icons.outbox_outlined,
                  label: _dispensedCountLabel(dispensed.length),
                ),
                _RefillStatusChip(
                  icon: Icons.fact_check_outlined,
                  label: '$needsReview needs review',
                ),
              ],
            ),
            if (dispensed.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _markDispensedForReview(context, dispensed),
                  icon: const Icon(Icons.playlist_add_check_outlined),
                  label: const Text('Review dispensed slots'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markDispensedForReview(
    BuildContext context,
    List<CarouselSlot> dispensed,
  ) async {
    try {
      // Bulk review is only a refill-state cleanup; dose outcomes are still
      // resolved through Today or Robot Face terminal actions.
      final dependencies = DoseyAppScope.of(context);
      for (final slot in dispensed) {
        await dependencies.carouselSlots.markNeedsReview(slot.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispensed slots marked for refill review.'),
        ),
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  static _RefillWarning _warningFor(int remaining, bool hasNoSlots) {
    if (hasNoSlots) {
      return const _RefillWarning(
        label: 'No doses loaded yet',
        icon: Icons.inventory_2_outlined,
        isWarning: true,
      );
    }
    if (remaining == 0) {
      return const _RefillWarning(
        label: 'Carousel empty',
        icon: Icons.error_outline,
        isWarning: true,
      );
    }
    if (remaining <= 3) {
      return const _RefillWarning(
        label: 'Refill soon',
        icon: Icons.warning_amber_outlined,
        isWarning: true,
      );
    }
    return const _RefillWarning(
      label: 'Refill on track',
      icon: Icons.check_circle_outline,
    );
  }

  static String _doseCountLabel(int count) {
    return count == 1 ? '1 dose remaining' : '$count doses remaining';
  }

  static String _dispensedCountLabel(int count) {
    return count == 1 ? '1 slot dispensed' : '$count slots dispensed';
  }
}

class _RefillWarning {
  const _RefillWarning({
    required this.label,
    required this.icon,
    this.isWarning = false,
  });

  final String label;
  final IconData icon;
  final bool isWarning;
}

class _RefillStatusChip extends StatelessWidget {
  const _RefillStatusChip({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isWarning
        ? colorScheme.onErrorContainer
        : colorScheme.onSurfaceVariant;
    final background = isWarning
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
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
      // Only enabled schedules with a prescription id can become physical slots.
      if (schedule.isEnabled &&
          schedule.prescriptionId != null &&
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

class _SlotCard extends StatefulWidget {
  const _SlotCard({
    required this.slot,
    required this.schedule,
    required this.prescription,
    required this.canRequestDispense,
  });

  final CarouselSlot slot;
  final ReminderSchedule? schedule;
  final Prescription? prescription;
  final bool canRequestDispense;

  @override
  State<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends State<_SlotCard> {
  var _isDispensing = false;

  @override
  void didUpdateWidget(_SlotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot.id != widget.slot.id) {
      _isDispensing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(widget.slot.slotNumber.toString())),
        title: Text('Slot ${widget.slot.slotNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(_doseLabel), Text(widget.slot.status.label)],
        ),
        trailing: _SlotAction(
          status: widget.slot.status,
          onMarkLoaded: _isDispensing ? null : () => _markLoaded(context),
          onMarkNeedsReview: _isDispensing
              ? null
              : () => _markNeedsReview(context),
          onDispense: _isDispensing || !widget.canRequestDispense
              ? null
              : () => _dispense(context),
        ),
      ),
    );
  }

  Future<void> _markNeedsReview(BuildContext context) async {
    try {
      await DoseyAppScope.of(
        context,
      ).carouselSlots.markNeedsReview(widget.slot.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot marked for refill review.')),
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  String get _doseLabel {
    final schedule = widget.schedule;
    final name =
        widget.prescription?.name ??
        schedule?.label ??
        widget.slot.prescriptionId;
    return schedule == null ? name : '${schedule.timeLabel} · $name';
  }

  Future<void> _markLoaded(BuildContext context) async {
    try {
      await DoseyAppScope.of(context).carouselSlots.markLoaded(widget.slot.id);
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
    if (_isDispensing) return;
    setState(() {
      _isDispensing = true;
    });
    final dependencies = DoseyAppScope.of(context);
    try {
      // Dispense moves the carousel and logs controller progress only. It must
      // not mark the dose taken.
      await CarouselDispenseCoordinator(
        carouselSlots: dependencies.carouselSlots,
        controller: dependencies.controller,
      ).dispenseLoadedSlot(
        slotId: widget.slot.id,
        doseId: _CarouselScreenState.doseIdForToday(widget.slot.scheduleId),
      );
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
    } finally {
      if (mounted) {
        setState(() {
          _isDispensing = false;
        });
      }
    }
  }
}

class _SlotAction extends StatelessWidget {
  const _SlotAction({
    required this.status,
    required this.onMarkLoaded,
    required this.onMarkNeedsReview,
    required this.onDispense,
  });

  final CarouselSlotStatus status;
  final VoidCallback? onMarkLoaded;
  final VoidCallback? onMarkNeedsReview;
  final VoidCallback? onDispense;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      CarouselSlotStatus.assigned => TextButton(
        onPressed: onMarkLoaded,
        child: const Text('Mark loaded'),
      ),
      CarouselSlotStatus.needsReview => TextButton(
        onPressed: onMarkLoaded,
        child: const Text('Mark loaded'),
      ),
      CarouselSlotStatus.loaded => TextButton(
        onPressed: onDispense,
        child: const Text('Dispense slot'),
      ),
      CarouselSlotStatus.dispensed => TextButton(
        onPressed: onMarkNeedsReview,
        child: const Text('Review refill'),
      ),
    };
  }
}
