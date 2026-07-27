import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/features/today/unresolved_missed_dose_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'selects the latest unresolved missed dose from today and yesterday',
    () {
      final now = DateTime(2040, 1, 2, 12);
      final schedules = <ReminderSchedule>[
        _schedule('morning', 8),
        _schedule('evening', 10),
      ];
      final events = <DoseLogEvent>[
        DoseLogEvent.doseMissed(
          doseId: 'morning:2040-01-01',
          occurredAt: DateTime(2040, 1, 1, 8, 30),
        ),
        DoseLogEvent.doseMissed(
          doseId: 'evening:2040-01-02',
          occurredAt: DateTime(2040, 1, 2, 10, 30),
        ),
      ];

      final result = UnresolvedMissedDoseHelper.latest(
        schedules,
        events,
        now: now,
      );

      expect(result?.doseId, 'evening:2040-01-02');
    },
  );

  test('recognition after the latest miss clears the dose', () {
    final now = DateTime(2040, 1, 2, 12);
    final events = <DoseLogEvent>[
      DoseLogEvent.doseMissed(
        doseId: 'morning:2040-01-02',
        occurredAt: DateTime(2040, 1, 2, 8, 30),
      ),
      DoseLogEvent.doseMissedRecognized(
        doseId: 'morning:2040-01-02',
        occurredAt: DateTime(2040, 1, 2, 9),
      ),
    ];

    expect(
      UnresolvedMissedDoseHelper.latest(
        <ReminderSchedule>[_schedule('morning', 8)],
        events,
        now: now,
      ),
      isNull,
    );
  });
}

ReminderSchedule _schedule(String id, int hour) {
  return ReminderSchedule(
    id: id,
    label: '$id dose',
    hour: hour,
    minute: 0,
    isEnabled: true,
    createdAt: DateTime(2040),
    updatedAt: DateTime(2040),
  );
}
