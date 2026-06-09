import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:flutter/material.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    final reminders = dependencies.reminders;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SafetyCard(),
        const SizedBox(height: 12),
        StreamBuilder<List<ReminderSchedule>>(
          stream: reminders.watchSchedules(),
          builder: (context, snapshot) {
            final schedules = snapshot.data ?? const <ReminderSchedule>[];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (schedules.isEmpty)
                      const Text('No local reminders yet.')
                    else
                      for (final schedule in schedules.take(3))
                        Text('${schedule.timeLabel} · ${schedule.label}'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await dependencies.doseLog.addEvent(
                            DoseLogEvent.doseTakenConfirmed(
                              doseId: 'manual-confirmation',
                              occurredAt: DateTime.now().toUtc(),
                            ),
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dose confirmation logged.'),
                            ),
                          );
                        } on Object catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Dose confirmation failed: $error'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirm dose taken manually'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Prototype safety'),
            SizedBox(height: 8),
            Text('Use candy, beads, dry beans, vitamins, or fake pills.'),
            SizedBox(height: 8),
            Text('Never mark a dose taken because the servo moved.'),
          ],
        ),
      ),
    );
  }
}
