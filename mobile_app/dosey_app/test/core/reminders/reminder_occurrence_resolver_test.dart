import 'package:dosey_app/core/reminders/reminder_occurrence_resolver.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ReminderOccurrenceResolver();
  final schedule = ReminderSchedule(
    id: 'morning',
    label: 'Morning',
    hour: 8,
    minute: 30,
    isEnabled: true,
    createdAt: DateTime.utc(2024),
    updatedAt: DateTime.utc(2024),
  );

  test(
    'resolves a configured Los Angeles date to its canonical UTC instant',
    () {
      final occurrence = resolver.resolve(
        schedule: schedule,
        localDate: DateTime.utc(2024, 7, 30),
        timezoneId: 'America/Los_Angeles',
      );

      expect(occurrence.localDate, '2024-07-30');
      expect(occurrence.scheduledAt, DateTime.utc(2024, 7, 30, 15, 30));
    },
  );

  test('resolves a spring gap and autumn fold deterministically', () {
    final gap = resolver.resolve(
      schedule: schedule.copyWith(hour: 2),
      localDate: DateTime.utc(2024, 3, 10),
      timezoneId: 'America/Los_Angeles',
    );
    final fold = resolver.resolve(
      schedule: schedule.copyWith(hour: 1),
      localDate: DateTime.utc(2024, 11, 3),
      timezoneId: 'America/Los_Angeles',
    );

    expect(gap.scheduledAt, DateTime.utc(2024, 3, 10, 10, 30));
    expect(fold.scheduledAt, DateTime.utc(2024, 11, 3, 8, 30));
  });
}
