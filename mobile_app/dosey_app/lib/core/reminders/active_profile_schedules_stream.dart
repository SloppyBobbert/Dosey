import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/schedules/schedule_profile.dart';

Stream<List<ReminderSchedule>> watchActiveProfileSchedules(
  ReminderRepository reminders,
  ScheduleProfile? activeProfile,
) {
  if (activeProfile == null) {
    return Stream<List<ReminderSchedule>>.value(const <ReminderSchedule>[]);
  }
  return reminders.watchSchedules(profileId: activeProfile.id);
}
