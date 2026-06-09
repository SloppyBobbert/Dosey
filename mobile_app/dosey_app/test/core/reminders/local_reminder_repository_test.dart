import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local reminder repository starts empty', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);

    expect(await repository.watchSchedules().first, isEmpty);
  });

  test('local reminder repository persists schedules', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final createdAt = DateTime.utc(2026, 6, 9, 8);
    final schedule = ReminderSchedule(
      id: 'morning',
      label: 'Morning dose',
      hour: 8,
      minute: 30,
      isEnabled: true,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    await repository.upsertSchedule(schedule);

    final schedules = await repository.watchSchedules().first;
    expect(schedules, hasLength(1));
    expect(schedules.single.id, 'morning');
    expect(schedules.single.label, 'Morning dose');
    expect(schedules.single.hour, 8);
    expect(schedules.single.minute, 30);
    expect(schedules.single.isEnabled, isTrue);
    expect(schedules.single.createdAt, createdAt);
    expect(schedules.single.updatedAt, createdAt);
  });

  test('local reminder repository deletes schedules', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalReminderRepository(database);
    final now = DateTime.utc(2026, 6, 9, 8);

    await repository.upsertSchedule(
      ReminderSchedule(
        id: 'evening',
        label: 'Evening dose',
        hour: 20,
        minute: 0,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.deleteSchedule('evening');

    expect(await repository.watchSchedules().first, isEmpty);
  });
}
