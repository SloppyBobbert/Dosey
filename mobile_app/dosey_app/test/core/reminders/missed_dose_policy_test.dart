import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_policy.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MissedDosePolicy', () {
    final morningSchedule = _schedule(id: 'morning-dose', hour: 8, minute: 0);

    test(
      'returns missed candidate after two-hour grace for enabled schedules',
      () {
        final now = DateTime(2026, 7, 9, 10, 1);

        final candidate = MissedDosePolicy.overdueDoseForDate(
          morningSchedule,
          const <DoseLogEvent>[],
          date: DateTime(2026, 7, 9),
          now: now,
        );

        expect(candidate, isNotNull);
        expect(
          candidate!.doseId,
          TodayNextDoseHelper.doseIdForDate(morningSchedule.id, now),
        );
        expect(candidate.event.kind, DoseLogEventKind.doseMissed);
        expect(candidate.event.marksDoseTaken, isFalse);
        expect(candidate.scheduledAt, DateTime(2026, 7, 9, 8));
      },
    );

    test('does not mark missed before the full grace period elapses', () {
      final candidate = MissedDosePolicy.overdueDoseForDate(
        morningSchedule,
        const <DoseLogEvent>[],
        date: DateTime(2026, 7, 9),
        now: DateTime(2026, 7, 9, 10),
      );

      expect(candidate, isNull);
    });

    test('does not mark disabled schedules missed', () {
      final candidate = MissedDosePolicy.overdueDoseForDate(
        _schedule(id: 'disabled-dose', hour: 8, minute: 0, isEnabled: false),
        const <DoseLogEvent>[],
        date: DateTime(2026, 7, 9),
        now: DateTime(2026, 7, 9, 12),
      );

      expect(candidate, isNull);
    });

    test('does not mark future doses missed', () {
      final candidate = MissedDosePolicy.overdueDoseForDate(
        morningSchedule,
        const <DoseLogEvent>[],
        date: DateTime(2026, 7, 10),
        now: DateTime(2026, 7, 9, 12),
      );

      expect(candidate, isNull);
    });

    test('terminal events prevent missed reconciliation', () {
      final doseId = TodayNextDoseHelper.doseIdForDate(
        morningSchedule.id,
        DateTime(2026, 7, 9, 9),
      );
      final candidate = MissedDosePolicy.overdueDoseForDate(
        morningSchedule,
        [
          DoseLogEvent.doseTakenConfirmed(
            doseId: doseId,
            occurredAt: DateTime(2026, 7, 9, 8, 30),
          ),
        ],
        date: DateTime(2026, 7, 9),
        now: DateTime(2026, 7, 9, 12),
      );

      expect(candidate, isNull);
    });

    test('does not backfill doses before the schedule existed', () {
      final candidate = MissedDosePolicy.overdueDoseForDate(
        _schedule(
          id: 'new-dose',
          hour: 8,
          minute: 0,
          createdAt: DateTime(2026, 7, 9, 8, 1),
        ),
        const <DoseLogEvent>[],
        date: DateTime(2026, 7, 9),
        now: DateTime(2026, 7, 9, 12),
      );

      expect(candidate, isNull);
    });

    test('does not backfill doses after a schedule edit past dose time', () {
      final candidate = MissedDosePolicy.overdueDoseForDate(
        _schedule(
          id: 'edited-dose',
          hour: 8,
          minute: 0,
          updatedAt: DateTime(2026, 7, 9, 8, 1),
        ),
        const <DoseLogEvent>[],
        date: DateTime(2026, 7, 9),
        now: DateTime(2026, 7, 9, 12),
      );

      expect(candidate, isNull);
    });
  });
}

ReminderSchedule _schedule({
  required String id,
  required int hour,
  required int minute,
  bool isEnabled = true,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final timestamp = DateTime(2026, 7, 1);
  return ReminderSchedule(
    id: id,
    label: id,
    hour: hour,
    minute: minute,
    isEnabled: isEnabled,
    createdAt: createdAt ?? timestamp,
    updatedAt: updatedAt ?? timestamp,
  );
}
