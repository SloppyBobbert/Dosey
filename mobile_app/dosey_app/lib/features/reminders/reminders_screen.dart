import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:flutter/material.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reminders = DoseyAppScope.of(context).reminders;

    return StreamBuilder<List<ReminderSchedule>>(
      stream: reminders.watchSchedules(),
      builder: (context, snapshot) {
        final schedules = snapshot.data ?? const <ReminderSchedule>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Local reminders',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (schedules.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No reminders yet. Add/edit controls come next.'),
                ),
              )
            else
              for (final schedule in schedules)
                ListTile(
                  title: Text(schedule.label),
                  subtitle: Text(schedule.timeLabel),
                  trailing: Icon(
                    schedule.isEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                  ),
                ),
          ],
        );
      },
    );
  }
}
