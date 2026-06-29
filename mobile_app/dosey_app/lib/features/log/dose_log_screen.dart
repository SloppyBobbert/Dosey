import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:flutter/material.dart';

class DoseLogScreen extends StatelessWidget {
  const DoseLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doseLog = DoseyAppScope.of(context).doseLog;

    return StreamBuilder<List<DoseLogEvent>>(
      stream: doseLog.watchEvents(),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <DoseLogEvent>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DoseLogHeroCard(events: events),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No local dose log events yet.'),
                ),
              )
            else
              for (final event in events)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(_iconFor(event.kind))),
                    title: Text(_labelFor(event.kind)),
                    subtitle: Text(event.doseId),
                    trailing: Icon(
                      event.marksDoseTaken
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  static String _labelFor(DoseLogEventKind kind) {
    return switch (kind) {
      DoseLogEventKind.controllerDispenseSucceeded =>
        'Controller dispense succeeded',
      DoseLogEventKind.doseTakenConfirmed => 'Dose taken confirmed',
      DoseLogEventKind.doseAlreadyTaken => 'Dose already taken',
      DoseLogEventKind.doseTakenEarly => 'Dose taken early',
      DoseLogEventKind.doseTakenLate => 'Dose taken late',
      DoseLogEventKind.doseVisibleConfirmed => 'Dose visible confirmed',
      DoseLogEventKind.doseSnoozed => 'Dose snoozed',
      DoseLogEventKind.caregiverHelpRequested => 'Caregiver help requested',
      DoseLogEventKind.doseSkipped => 'Dose skipped',
      DoseLogEventKind.doseMissed => 'Dose missed',
      DoseLogEventKind.error => 'Error',
    };
  }

  static IconData _iconFor(DoseLogEventKind kind) {
    return switch (kind) {
      DoseLogEventKind.controllerDispenseSucceeded => Icons.play_circle_outline,
      DoseLogEventKind.doseTakenConfirmed => Icons.check_circle_outline,
      DoseLogEventKind.doseAlreadyTaken => Icons.task_alt_outlined,
      DoseLogEventKind.doseTakenEarly => Icons.fast_forward_outlined,
      DoseLogEventKind.doseTakenLate => Icons.history_toggle_off_outlined,
      DoseLogEventKind.doseVisibleConfirmed => Icons.visibility_outlined,
      DoseLogEventKind.doseSnoozed => Icons.snooze_outlined,
      DoseLogEventKind.caregiverHelpRequested => Icons.support_agent_outlined,
      DoseLogEventKind.doseSkipped => Icons.skip_next_outlined,
      DoseLogEventKind.doseMissed => Icons.schedule_outlined,
      DoseLogEventKind.error => Icons.error_outline,
    };
  }
}

class _DoseLogHeroCard extends StatelessWidget {
  const _DoseLogHeroCard({required this.events});

  final List<DoseLogEvent> events;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final confirmedTaken = events.where((event) => event.marksDoseTaken).length;
    final movementOrReview = events.length - confirmedTaken;

    return Card(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.onSecondaryContainer,
                  foregroundColor: colorScheme.secondaryContainer,
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local audit trail',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Dose history',
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSecondaryContainer,
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
              'Dose log',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Controller movement, skipped, missed, and taken confirmations stay separate.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DoseLogHeroChip(
                  icon: Icons.list_alt_outlined,
                  label: '${events.length} local events',
                ),
                _DoseLogHeroChip(
                  icon: Icons.check_circle_outline,
                  label: '$confirmedTaken confirmed taken',
                ),
                _DoseLogHeroChip(
                  icon: Icons.info_outline,
                  label: '$movementOrReview movement or review',
                ),
                const _DoseLogHeroChip(
                  icon: Icons.verified_user_outlined,
                  label: 'Manual confirmation only',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseLogHeroChip extends StatelessWidget {
  const _DoseLogHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.onSecondaryContainer.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
