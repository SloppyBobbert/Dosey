import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';
import 'package:flutter/material.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    final reminders = dependencies.reminders;

    return StreamBuilder<List<Prescription>>(
      stream: dependencies.prescriptions.watchPrescriptions(),
      builder: (context, prescriptionSnapshot) {
        final prescriptionsById = _prescriptionsById(
          prescriptionSnapshot.data ?? const <Prescription>[],
        );

        return StreamBuilder<ScheduleProfile?>(
          stream: dependencies.scheduleProfiles.watchActiveProfile(),
          builder: (context, profileSnapshot) {
            return StreamBuilder<List<ReminderSchedule>>(
              stream: _activeSchedulesStream(reminders, profileSnapshot.data),
              builder: (context, reminderSnapshot) {
                final schedules =
                    reminderSnapshot.data ?? const <ReminderSchedule>[];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TodayDoseContent(
                        schedules: schedules,
                        prescriptionsById: prescriptionsById,
                      ),
                      const SizedBox(height: 12),
                      const _SafetyCard(),
                      const SizedBox(height: 12),
                      _ScheduleTimelineCard(
                        schedules: schedules,
                        prescriptionsById: prescriptionsById,
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

  /// Uses only the active schedule profile for the robot-facing Today view.
  static Stream<List<ReminderSchedule>> _activeSchedulesStream(
    ReminderRepository reminders,
    ScheduleProfile? activeProfile,
  ) {
    if (activeProfile == null) {
      return Stream<List<ReminderSchedule>>.value(const <ReminderSchedule>[]);
    }
    return reminders.watchSchedules(profileId: activeProfile.id);
  }

  /// Joins schedules to the user's saved prescription metadata for display
  /// only; this does not verify medications, identify pills, or advise dosing.
  static Map<String, Prescription> _prescriptionsById(
    List<Prescription> prescriptions,
  ) {
    return {
      for (final prescription in prescriptions) prescription.id: prescription,
    };
  }

  static ReminderSchedule? _currentSchedule(
    List<ReminderSchedule> schedules,
    List<DoseLogEvent> events,
  ) {
    for (final schedule in schedules) {
      final doseId = _doseIdForToday(schedule.id);
      if (schedule.isEnabled && !_hasTerminalEventForDose(events, doseId)) {
        return schedule;
      }
    }
    return null;
  }

  static DoseLogEvent? _latestEventForDose(
    List<DoseLogEvent> events,
    String doseId,
  ) {
    DoseLogEvent? latest;
    for (final event in events) {
      if (event.doseId == doseId &&
          (latest == null || event.occurredAt.isAfter(latest.occurredAt))) {
        latest = event;
      }
    }
    return latest;
  }

  static bool _hasTerminalEventForDose(
    List<DoseLogEvent> events,
    String doseId,
  ) {
    for (final event in events) {
      if (event.doseId == doseId && _isTerminalDoseEvent(event)) {
        return true;
      }
    }
    return false;
  }

  static bool _isTerminalDoseEvent(DoseLogEvent event) {
    return switch (event.kind) {
      DoseLogEventKind.doseTakenConfirmed ||
      DoseLogEventKind.doseAlreadyTaken ||
      DoseLogEventKind.doseTakenEarly ||
      DoseLogEventKind.doseTakenLate ||
      DoseLogEventKind.doseSkipped ||
      DoseLogEventKind.doseMissed => true,
      _ => false,
    };
  }

  static String _doseIdForToday(String scheduleId) {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$scheduleId:${now.year}-$month-$day';
  }

  static Future<void> _logDoseAction(
    BuildContext context,
    DoseLogEvent event,
    String successMessage,
  ) async {
    try {
      await DoseyAppScope.of(context).doseLog.addEvent(event);
      if (!context.mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text('Dose action failed: $error')),
      );
    }
  }
}

class _TodayDoseContent extends StatelessWidget {
  const _TodayDoseContent({
    required this.schedules,
    required this.prescriptionsById,
  });

  final List<ReminderSchedule> schedules;
  final Map<String, Prescription> prescriptionsById;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DoseLogEvent>>(
      stream: DoseyAppScope.of(context).doseLog.watchEvents(),
      builder: (context, logSnapshot) {
        final events = logSnapshot.data ?? const <DoseLogEvent>[];
        final currentSchedule = TodayScreen._currentSchedule(schedules, events);
        final currentDoseId = currentSchedule == null
            ? null
            : TodayScreen._doseIdForToday(currentSchedule.id);

        final dependencies = DoseyAppScope.of(context);

        return StreamBuilder<List<CarouselSlot>>(
          stream: currentSchedule == null
              ? Stream<List<CarouselSlot>>.value(const <CarouselSlot>[])
              : dependencies.carouselSlots.watchSlots(
                  profileId: currentSchedule.profileId,
                ),
          builder: (context, slotSnapshot) {
            final loadedSlot = currentSchedule == null
                ? null
                : _CurrentDoseSection.loadedSlotForSchedule(
                    slotSnapshot.data ?? const <CarouselSlot>[],
                    currentSchedule,
                  );
            final latestEvent = currentDoseId == null
                ? null
                : TodayScreen._latestEventForDose(events, currentDoseId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TodayHeroCard(
                  currentSchedule: currentSchedule,
                  prescription: currentSchedule == null
                      ? null
                      : prescriptionsById[currentSchedule.prescriptionId],
                  latestEvent: latestEvent,
                  loadedSlot: loadedSlot,
                  scheduledDoseCount: schedules
                      .where((s) => s.isEnabled)
                      .length,
                  onConfirmDoseTaken: () => TodayScreen._logDoseAction(
                    context,
                    DoseLogEvent.doseTakenConfirmed(
                      doseId: currentDoseId ?? 'manual-confirmation',
                      occurredAt: DateTime.now().toUtc(),
                    ),
                    'Dose confirmation logged.',
                  ),
                ),
                const SizedBox(height: 12),
                _CurrentDoseSection(
                  events: events,
                  currentSchedule: currentSchedule,
                  currentDoseId: currentDoseId,
                  prescriptionsById: prescriptionsById,
                  loadedSlot: loadedSlot,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CurrentDoseSection extends StatelessWidget {
  const _CurrentDoseSection({
    required this.events,
    required this.currentSchedule,
    required this.currentDoseId,
    required this.prescriptionsById,
    required this.loadedSlot,
  });

  final List<DoseLogEvent> events;
  final ReminderSchedule? currentSchedule;
  final String? currentDoseId;
  final Map<String, Prescription> prescriptionsById;
  final CarouselSlot? loadedSlot;

  @override
  Widget build(BuildContext context) {
    final currentSchedule = this.currentSchedule;
    final currentDoseId = this.currentDoseId;
    if (currentSchedule == null || currentDoseId == null) {
      return const SizedBox.shrink();
    }
    final latestEvent = TodayScreen._latestEventForDose(events, currentDoseId);
    return _CurrentDoseCard(
      schedule: currentSchedule,
      prescription: prescriptionsById[currentSchedule.prescriptionId],
      latestEvent: latestEvent,
      loadedSlot: loadedSlot,
      onDispenseLoadedSlot: loadedSlot == null
          ? null
          : () => _dispenseLoadedSlot(context, loadedSlot!, currentDoseId),
      onSnoozeDose: () => TodayScreen._logDoseAction(
        context,
        DoseLogEvent.doseSnoozed(
          doseId: currentDoseId,
          occurredAt: DateTime.now().toUtc(),
        ),
        'Reminder snoozed for 10 minutes.',
      ),
      onConfirmTaken: () => TodayScreen._logDoseAction(
        context,
        DoseLogEvent.doseTakenConfirmed(
          doseId: currentDoseId,
          occurredAt: DateTime.now().toUtc(),
        ),
        'Dose marked taken.',
      ),
      onAlreadyTaken: () => TodayScreen._logDoseAction(
        context,
        DoseLogEvent.doseAlreadyTaken(
          doseId: currentDoseId,
          occurredAt: DateTime.now().toUtc(),
        ),
        'Already-taken dose logged.',
      ),
      onTakenEarly: () => TodayScreen._logDoseAction(
        context,
        DoseLogEvent.doseTakenEarly(
          doseId: currentDoseId,
          occurredAt: DateTime.now().toUtc(),
        ),
        'Early dose logged.',
      ),
      onTakenLate: () => TodayScreen._logDoseAction(
        context,
        DoseLogEvent.doseTakenLate(
          doseId: currentDoseId,
          occurredAt: DateTime.now().toUtc(),
        ),
        'Late dose logged.',
      ),
      onConfirmVisible:
          latestEvent?.kind == DoseLogEventKind.controllerDispenseSucceeded
          ? () => TodayScreen._logDoseAction(
              context,
              DoseLogEvent.doseVisibleConfirmed(
                doseId: currentDoseId,
                occurredAt: DateTime.now().toUtc(),
              ),
              'Visible dose logged. Confirm taken only after the dose is taken.',
            )
          : null,
      onAskCaregiver: () => TodayScreen._logDoseAction(
        context,
        DoseLogEvent.caregiverHelpRequested(
          doseId: currentDoseId,
          occurredAt: DateTime.now().toUtc(),
        ),
        'Caregiver request noted locally. Contact your caregiver, pharmacist, or doctor if you are unsure what to do.',
      ),
      onSkipDose: () => TodayScreen._logDoseAction(
        context,
        DoseLogEvent.doseSkipped(
          doseId: currentDoseId,
          occurredAt: DateTime.now().toUtc(),
        ),
        'Dose skipped.',
      ),
      onMarkMissed: () => TodayScreen._logDoseAction(
        context,
        DoseLogEvent.doseMissed(
          doseId: currentDoseId,
          occurredAt: DateTime.now().toUtc(),
        ),
        'This dose was missed. Follow your prescription instructions or ask your caregiver, pharmacist, or doctor.',
      ),
    );
  }

  static CarouselSlot? loadedSlotForSchedule(
    List<CarouselSlot> slots,
    ReminderSchedule schedule,
  ) {
    for (final slot in slots) {
      if (slot.scheduleId == schedule.id &&
          slot.status == CarouselSlotStatus.loaded) {
        return slot;
      }
    }
    return null;
  }

  static Future<void> _dispenseLoadedSlot(
    BuildContext context,
    CarouselSlot slot,
    String doseId,
  ) async {
    try {
      final dependencies = DoseyAppScope.of(context);
      await dependencies.controller.requestDispense(doseId: doseId);
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

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({
    required this.currentSchedule,
    required this.prescription,
    required this.latestEvent,
    required this.loadedSlot,
    required this.scheduledDoseCount,
    required this.onConfirmDoseTaken,
  });

  final ReminderSchedule? currentSchedule;
  final Prescription? prescription;
  final DoseLogEvent? latestEvent;
  final CarouselSlot? loadedSlot;
  final int scheduledDoseCount;
  final VoidCallback onConfirmDoseTaken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentSchedule = this.currentSchedule;
    final prescription = this.prescription;
    final doseTitle = currentSchedule == null
        ? 'Dosey is ready for your day'
        : prescription?.name ?? currentSchedule.label;
    final doseSubtitle = currentSchedule == null
        ? 'Review reminders, keep prototype checks visible, and confirm doses only after you know they were taken.'
        : '${currentSchedule.timeLabel} · ${prescription?.pillType.label ?? 'Scheduled dose'}';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer.withValues(alpha: 0.78),
            colorScheme.surface,
          ],
        ),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSchedule == null ? 'Today' : 'Next dose',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        doseTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        doseSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.78,
                          ),
                          fontWeight: currentSchedule == null
                              ? FontWeight.w400
                              : FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    currentSchedule == null
                        ? Icons.wb_sunny_outlined
                        : Icons.medication_outlined,
                    color: colorScheme.primary,
                    size: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _TodayHeroStatusChips(
              scheduledDoseCount: scheduledDoseCount,
              hasActiveDose: currentSchedule != null,
              latestEvent: latestEvent,
              loadedSlot: loadedSlot,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onConfirmDoseTaken,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm dose taken manually'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayHeroStatusChips extends StatelessWidget {
  const _TodayHeroStatusChips({
    required this.scheduledDoseCount,
    required this.hasActiveDose,
    required this.latestEvent,
    required this.loadedSlot,
  });

  final int scheduledDoseCount;
  final bool hasActiveDose;
  final DoseLogEvent? latestEvent;
  final CarouselSlot? loadedSlot;

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    return StreamBuilder<ControllerSnapshot>(
      stream: dependencies.controller.watchController(),
      builder: (context, controllerSnapshot) {
        final controller =
            controllerSnapshot.data ?? const ControllerSnapshot.disconnected();
        return StreamBuilder<bool>(
          stream: dependencies.settings.watchSafetyAcknowledged(),
          builder: (context, safetySnapshot) {
            final safetyAcknowledged = safetySnapshot.data ?? false;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const _StatusPill(
                  icon: Icons.phone_android,
                  label: 'Local-only',
                ),
                const _StatusPill(
                  icon: Icons.science_outlined,
                  label: 'Prototype-safe',
                ),
                const _StatusPill(
                  icon: Icons.check_circle_outline,
                  label: 'Manual confirmation',
                ),
                _StatusPill(
                  icon: Icons.health_and_safety_outlined,
                  label: safetyAcknowledged
                      ? 'Safety acknowledged'
                      : 'Safety to review',
                ),
                _StatusPill(
                  icon: Icons.memory_outlined,
                  label:
                      controller.connectionState ==
                          ControllerConnectionState.connected
                      ? 'Controller connected'
                      : 'Controller offline',
                ),
                _StatusPill(
                  icon: hasActiveDose
                      ? Icons.event_available_outlined
                      : Icons.event_busy_outlined,
                  label: hasActiveDose ? 'Active schedule' : 'No active dose',
                ),
                if (scheduledDoseCount > 0)
                  _StatusPill(
                    icon: Icons.timeline_outlined,
                    label: '$scheduledDoseCount scheduled today',
                  ),
                if (loadedSlot != null)
                  _StatusPill(
                    icon: Icons.inventory_2_outlined,
                    label: 'Loaded slot ${loadedSlot!.slotNumber}',
                  ),
                if (latestEvent != null)
                  _StatusPill(
                    icon: Icons.history_outlined,
                    label: _latestEventLabel(latestEvent!),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  static String _latestEventLabel(DoseLogEvent event) {
    return switch (event.kind) {
      DoseLogEventKind.controllerDispenseSucceeded => 'Movement logged',
      DoseLogEventKind.doseTakenConfirmed => 'Taken logged',
      DoseLogEventKind.doseAlreadyTaken => 'Already taken logged',
      DoseLogEventKind.doseTakenEarly => 'Taken early logged',
      DoseLogEventKind.doseTakenLate => 'Taken late logged',
      DoseLogEventKind.doseVisibleConfirmed => 'Visible logged',
      DoseLogEventKind.doseSnoozed => 'Snoozed logged',
      DoseLogEventKind.caregiverHelpRequested => 'Caregiver asked',
      DoseLogEventKind.doseSkipped => 'Skipped logged',
      DoseLogEventKind.doseMissed => 'Missed logged',
      _ => 'Event logged',
    };
  }
}

class _CurrentDoseCard extends StatelessWidget {
  const _CurrentDoseCard({
    required this.schedule,
    required this.prescription,
    required this.latestEvent,
    required this.loadedSlot,
    required this.onDispenseLoadedSlot,
    required this.onSnoozeDose,
    required this.onConfirmTaken,
    required this.onAlreadyTaken,
    required this.onTakenEarly,
    required this.onTakenLate,
    required this.onConfirmVisible,
    required this.onAskCaregiver,
    required this.onSkipDose,
    required this.onMarkMissed,
  });

  final ReminderSchedule schedule;
  final Prescription? prescription;
  final DoseLogEvent? latestEvent;
  final CarouselSlot? loadedSlot;
  final VoidCallback? onDispenseLoadedSlot;
  final VoidCallback onSnoozeDose;
  final VoidCallback onConfirmTaken;
  final VoidCallback onAlreadyTaken;
  final VoidCallback onTakenEarly;
  final VoidCallback onTakenLate;
  final VoidCallback? onConfirmVisible;
  final VoidCallback onAskCaregiver;
  final VoidCallback onSkipDose;
  final VoidCallback onMarkMissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scheduleName = prescription?.name ?? schedule.label;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.medication_liquid_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current dose',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${schedule.timeLabel} · $scheduleName'),
                      if (prescription != null) ...[
                        const SizedBox(height: 2),
                        Text(prescription!.pillType.label),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (latestEvent != null) ...[
              const SizedBox(height: 12),
              _DoseStatusBanner(event: latestEvent!),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onConfirmTaken,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm taken'),
                ),
                OutlinedButton.icon(
                  onPressed: onAlreadyTaken,
                  icon: const Icon(Icons.task_alt_outlined),
                  label: const Text('Already taken'),
                ),
                OutlinedButton.icon(
                  onPressed: onTakenEarly,
                  icon: const Icon(Icons.fast_forward_outlined),
                  label: const Text('Taken early'),
                ),
                OutlinedButton.icon(
                  onPressed: onTakenLate,
                  icon: const Icon(Icons.history_toggle_off_outlined),
                  label: const Text('Taken late'),
                ),
                if (loadedSlot != null)
                  FilledButton.tonalIcon(
                    onPressed: onDispenseLoadedSlot,
                    icon: const Icon(Icons.play_arrow),
                    label: Text('Dispense from slot ${loadedSlot!.slotNumber}'),
                  ),
                if (onConfirmVisible != null)
                  FilledButton.tonalIcon(
                    onPressed: onConfirmVisible,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Dose visible'),
                  ),
                OutlinedButton.icon(
                  onPressed: onSnoozeDose,
                  icon: const Icon(Icons.snooze_outlined),
                  label: const Text('Snooze 10 min'),
                ),
                OutlinedButton.icon(
                  onPressed: onAskCaregiver,
                  icon: const Icon(Icons.support_agent_outlined),
                  label: const Text('Ask caregiver'),
                ),
                OutlinedButton.icon(
                  onPressed: onSkipDose,
                  icon: const Icon(Icons.skip_next_outlined),
                  label: const Text('Skip dose'),
                ),
                OutlinedButton.icon(
                  onPressed: onMarkMissed,
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Mark missed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseStatusBanner extends StatelessWidget {
  const _DoseStatusBanner({required this.event});

  final DoseLogEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, label) = switch (event.kind) {
      DoseLogEventKind.doseTakenConfirmed => (
        Icons.check_circle_outline,
        'Confirmed taken',
      ),
      DoseLogEventKind.doseAlreadyTaken => (
        Icons.task_alt_outlined,
        'Already taken',
      ),
      DoseLogEventKind.doseTakenEarly => (
        Icons.fast_forward_outlined,
        'Taken early',
      ),
      DoseLogEventKind.doseTakenLate => (
        Icons.history_toggle_off_outlined,
        'Taken late',
      ),
      DoseLogEventKind.doseVisibleConfirmed => (
        Icons.visibility_outlined,
        'Dose visible',
      ),
      DoseLogEventKind.doseSnoozed => (Icons.snooze_outlined, 'Snoozed'),
      DoseLogEventKind.caregiverHelpRequested => (
        Icons.support_agent_outlined,
        'Caregiver asked',
      ),
      DoseLogEventKind.doseSkipped => (Icons.skip_next_outlined, 'Skipped'),
      DoseLogEventKind.doseMissed => (Icons.schedule_outlined, 'Missed'),
      DoseLogEventKind.controllerDispenseSucceeded => (
        Icons.play_circle_outline,
        'Dispense moved',
      ),
      _ => (Icons.info_outline, 'Logged'),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prototype safety',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use candy, beads, dry beans, vitamins, or fake pills.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Never mark a dose taken because the servo moved.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTimelineCard extends StatelessWidget {
  const _ScheduleTimelineCard({
    required this.schedules,
    required this.prescriptionsById,
  });

  final List<ReminderSchedule> schedules;
  final Map<String, Prescription> prescriptionsById;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next schedule timeline',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Scheduled reminders',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const _TimelineHeaderChip(),
              ],
            ),
            const SizedBox(height: 10),
            if (schedules.isEmpty)
              const _EmptyReminderState()
            else
              for (final indexed in schedules.take(4).indexed)
                _TimelineRow(
                  statusLabel: indexed.$1 == 0 ? 'Now watching' : 'Later today',
                  schedule: indexed.$2,
                  prescription: prescriptionsById[indexed.$2.prescriptionId],
                ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReminderState extends StatelessWidget {
  const _EmptyReminderState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_available_outlined, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            'No reminders scheduled for today.',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first schedule from the Schedule tab.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineHeaderChip extends StatelessWidget {
  const _TimelineHeaderChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Up next',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.statusLabel,
    required this.schedule,
    required this.prescription,
  });

  final String statusLabel;
  final ReminderSchedule schedule;
  final Prescription? prescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scheduleName = prescription?.name ?? schedule.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 2,
                  height: 52,
                  color: colorScheme.outlineVariant,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                schedule.timeLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scheduleName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    schedule.isEnabled ? 'Enabled reminder' : 'Reminder paused',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (prescription != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      prescription!.pillType.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              schedule.isEnabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: schedule.isEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
