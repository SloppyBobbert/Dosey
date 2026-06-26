import 'package:dosey_app/app/dosey_app_scope.dart';
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
                      _ReminderPreviewCard(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Dose action failed: $error')));
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TodayHeroCard(
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
            ),
          ],
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
  });

  final List<DoseLogEvent> events;
  final ReminderSchedule? currentSchedule;
  final String? currentDoseId;
  final Map<String, Prescription> prescriptionsById;

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
      onConfirmTaken: () => TodayScreen._logDoseAction(
        context,
        DoseLogEvent.doseTakenConfirmed(
          doseId: currentDoseId,
          occurredAt: DateTime.now().toUtc(),
        ),
        'Dose marked taken.',
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
}

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({required this.onConfirmDoseTaken});

  final VoidCallback onConfirmDoseTaken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                        'Today',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dosey is ready for your day',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Review reminders, keep prototype checks visible, and confirm doses only after you know they were taken.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.78,
                          ),
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
                    Icons.wb_sunny_outlined,
                    color: colorScheme.primary,
                    size: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _StatusPill(icon: Icons.phone_android, label: 'Local-only'),
                _StatusPill(
                  icon: Icons.science_outlined,
                  label: 'Prototype-safe',
                ),
                _StatusPill(
                  icon: Icons.check_circle_outline,
                  label: 'Manual confirmation',
                ),
              ],
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

class _CurrentDoseCard extends StatelessWidget {
  const _CurrentDoseCard({
    required this.schedule,
    required this.prescription,
    required this.latestEvent,
    required this.onConfirmTaken,
    required this.onSkipDose,
    required this.onMarkMissed,
  });

  final ReminderSchedule schedule;
  final Prescription? prescription;
  final DoseLogEvent? latestEvent;
  final VoidCallback onConfirmTaken;
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
      DoseLogEventKind.doseSkipped => (Icons.skip_next_outlined, 'Skipped'),
      DoseLogEventKind.doseMissed => (Icons.schedule_outlined, 'Missed'),
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

class _ReminderPreviewCard extends StatelessWidget {
  const _ReminderPreviewCard({
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
            Text(
              'Scheduled reminders',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (schedules.isEmpty)
              const _EmptyReminderState()
            else
              for (final schedule in schedules.take(3))
                _ReminderRow(
                  schedule: schedule,
                  prescription: prescriptionsById[schedule.prescriptionId],
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

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.schedule, required this.prescription});

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
                    scheduleName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
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
