import 'package:dosey_app/core/reminders/reminder_occurrence_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = ReminderOccurrenceResolver();

  test('resolves a Los Angeles wall time and preserves its local date', () {
    final resolved = resolver.resolve(
      localDate: DateTime.utc(2024, 7, 30),
      hour: 8,
      minute: 30,
      timezoneId: 'America/Los_Angeles',
    );

    expect(resolved.scheduledAtUtc, DateTime.utc(2024, 7, 30, 15, 30));
    expect(resolved.localDate, '2024-07-30');
  });

  test(
    'normalizes LA spring gaps and selects the earlier autumn-fold instant',
    () {
      final gap = resolver.resolve(
        localDate: DateTime.utc(2024, 3, 10),
        hour: 2,
        minute: 30,
        timezoneId: 'America/Los_Angeles',
      );
      final fold = resolver.resolve(
        localDate: DateTime.utc(2024, 11, 3),
        hour: 1,
        minute: 30,
        timezoneId: 'America/Los_Angeles',
      );

      expect(gap.scheduledAtUtc, DateTime.utc(2024, 3, 10, 10, 30));
      expect(gap.localDate, '2024-03-10');
      expect(fold.scheduledAtUtc, DateTime.utc(2024, 11, 3, 8, 30));
      expect(fold.localDate, '2024-11-03');
    },
  );

  test('rejects unknown timezones deterministically', () {
    expect(
      () => resolver.resolve(
        localDate: DateTime.utc(2024, 1, 1),
        hour: 8,
        minute: 30,
        timezoneId: 'Mars/Olympus_Mons',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects invalid wall-clock values and non-date markers', () {
    for (final values in [
      (hour: -1, minute: 0),
      (hour: 24, minute: 0),
      (hour: 8, minute: 60),
    ]) {
      expect(
        () => resolver.resolve(
          localDate: DateTime.utc(2024, 1, 1),
          hour: values.hour,
          minute: values.minute,
          timezoneId: 'UTC',
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => resolver.resolve(
        localDate: DateTime.utc(2024, 1, 1, 1),
        hour: 8,
        minute: 30,
        timezoneId: 'UTC',
      ),
      throwsArgumentError,
    );
  });
}
