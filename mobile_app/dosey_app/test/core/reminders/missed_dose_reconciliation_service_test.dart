import 'dart:async';

import 'package:dosey_app/core/carousel/carousel_slot.dart';
import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/core/reminders/missed_dose_reconciliation_service.dart';
import 'package:dosey_app/core/reminders/reminder_schedule.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/today/today_next_dose_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MissedDoseReconciliationService', () {
    test(
      'logs one missed event for each overdue unresolved dose from today and yesterday',
      () async {
        final reminders = _FakeReminderRepository([
          _schedule(id: 'yesterday-dose', hour: 8, minute: 0),
          _schedule(id: 'today-dose', hour: 9, minute: 0),
          _schedule(id: 'future-dose', hour: 23, minute: 0),
        ]);
        final doseLog = _FakeDoseLogRepository();
        final service = MissedDoseReconciliationService(
          reminders: reminders,
          doseLog: doseLog,
          now: () => DateTime(2026, 7, 9, 12, 30),
        );

        await service.reconcile();

        expect(doseLog.addedEvents.map((event) => event.doseId).toList(), [
          TodayNextDoseHelper.doseIdForDate(
            'yesterday-dose',
            DateTime(2026, 7, 8),
          ),
          TodayNextDoseHelper.doseIdForDate('today-dose', DateTime(2026, 7, 8)),
          TodayNextDoseHelper.doseIdForDate(
            'future-dose',
            DateTime(2026, 7, 8),
          ),
          TodayNextDoseHelper.doseIdForDate(
            'yesterday-dose',
            DateTime(2026, 7, 9),
          ),
          TodayNextDoseHelper.doseIdForDate('today-dose', DateTime(2026, 7, 9)),
        ]);
        expect(
          doseLog.addedEvents.every((event) => !event.marksDoseTaken),
          isTrue,
        );
      },
    );

    test('skips a dose date that already has a terminal event', () async {
      final reminders = _FakeReminderRepository([
        _schedule(id: 'resolved-dose', hour: 8, minute: 0),
      ]);
      final doseId = TodayNextDoseHelper.doseIdForDate(
        'resolved-dose',
        DateTime(2026, 7, 9),
      );
      final doseLog = _FakeDoseLogRepository(
        events: [
          DoseLogEvent.doseMissed(
            doseId: doseId,
            occurredAt: DateTime(2026, 7, 9, 10, 1),
          ),
        ],
      );
      final service = MissedDoseReconciliationService(
        reminders: reminders,
        doseLog: doseLog,
        now: () => DateTime(2026, 7, 9, 12),
      );

      await service.reconcile();

      expect(doseLog.addedEvents.map((event) => event.doseId).toList(), [
        TodayNextDoseHelper.doseIdForDate(
          'resolved-dose',
          DateTime(2026, 7, 8),
        ),
      ]);
    });

    test('only checks today and yesterday for closed-app catchup', () async {
      final reminders = _FakeReminderRepository([
        _schedule(id: 'old-dose', hour: 8, minute: 0),
      ]);
      final doseLog = _FakeDoseLogRepository();
      final service = MissedDoseReconciliationService(
        reminders: reminders,
        doseLog: doseLog,
        now: () => DateTime(2026, 7, 9, 12),
      );

      await service.reconcile();

      expect(
        doseLog.addedEvents.any((event) => event.doseId.contains('2026-07-07')),
        isFalse,
      );
    });

    test(
      'retires loaded and dispensed slots when auto-marking a missed dose',
      () async {
        final database = DoseyDatabase.inMemory();
        addTearDown(database.close);
        final now = DateTime(2026, 7, 9, 12);
        final reminderRepository = LocalReminderRepository(database);
        final reminders = _FakeReminderRepository([
          _schedule(id: 'loaded-dose', hour: 8, minute: 0),
          _schedule(id: 'dispensed-dose', hour: 9, minute: 0),
        ]);
        final doseLog = DriftDoseLogRepository(database);
        final carouselSlots = LocalCarouselSlotRepository(database);
        final service = MissedDoseReconciliationService(
          reminders: reminders,
          doseLog: doseLog,
          carouselSlots: carouselSlots,
          database: database,
          now: () => now,
        );

        await reminderRepository.upsertSchedule(
          _schedule(
            id: 'loaded-dose',
            hour: 8,
            minute: 0,
            prescriptionId: 'prescription-slot-loaded',
          ),
        );
        await reminderRepository.upsertSchedule(
          _schedule(
            id: 'dispensed-dose',
            hour: 9,
            minute: 0,
            prescriptionId: 'prescription-slot-dispensed',
          ),
        );
        await carouselSlots.assignSlot(
          _slot(
            id: 'slot-loaded',
            scheduleId: 'loaded-dose',
            status: CarouselSlotStatus.loaded,
          ),
        );
        await carouselSlots.assignSlot(
          _slot(
            id: 'slot-dispensed',
            scheduleId: 'dispensed-dose',
            status: CarouselSlotStatus.dispensed,
          ),
        );

        await service.reconcile();

        final slots = await carouselSlots.watchSlots().first;
        expect(
          slots.map((slot) => slot.status).toList(),
          everyElement(CarouselSlotStatus.needsReview),
        );
        final events = await doseLog.watchEvents().first;
        expect(
          events.where((event) => event.kind == DoseLogEventKind.doseMissed),
          hasLength(4),
        );
      },
    );

    test(
      'startup reconciliation stays one-shot for terminal missed events',
      () async {
        final database = DoseyDatabase.inMemory();
        addTearDown(database.close);
        final now = DateTime(2026, 7, 9, 12);
        final reminders = _FakeReminderRepository([
          _schedule(id: 'dose-a', hour: 8, minute: 0),
        ]);
        final doseLog = DriftDoseLogRepository(database);
        final service = MissedDoseReconciliationService(
          reminders: reminders,
          doseLog: doseLog,
          database: database,
          now: () => now,
        );

        await service.reconcile();
        await service.reconcile();

        final events = await doseLog.watchEvents().first;
        expect(
          events.where((event) => event.kind == DoseLogEventKind.doseMissed),
          hasLength(2),
        );
      },
    );

    test(
      'continues reconciling later candidates after one write fails',
      () async {
        final reminders = _FakeReminderRepository([
          _schedule(id: 'first-dose', hour: 8, minute: 0),
          _schedule(id: 'second-dose', hour: 9, minute: 0),
        ]);
        final doseLog = _FakeDoseLogRepository()..remainingAddFailures = 1;
        final service = MissedDoseReconciliationService(
          reminders: reminders,
          doseLog: doseLog,
          now: () => DateTime(2026, 7, 9, 12),
        );

        await service.reconcile();

        expect(doseLog.addAttempts, 4);
        expect(doseLog.addedEvents.map((event) => event.doseId).toList(), [
          TodayNextDoseHelper.doseIdForDate(
            'second-dose',
            DateTime(2026, 7, 8),
          ),
          TodayNextDoseHelper.doseIdForDate('first-dose', DateTime(2026, 7, 9)),
          TodayNextDoseHelper.doseIdForDate(
            'second-dose',
            DateTime(2026, 7, 9),
          ),
        ]);
      },
    );
  });
}

class _FakeReminderRepository implements ReminderRepository {
  _FakeReminderRepository(this.schedules);

  final List<ReminderSchedule> schedules;

  @override
  Stream<List<ReminderSchedule>> watchSchedules({String? profileId}) {
    return Stream.value(schedules);
  }

  @override
  Future<void> deleteSchedule(String id) async {}

  @override
  Future<void> upsertSchedule(ReminderSchedule schedule) async {}
}

class _FakeDoseLogRepository implements DoseLogRepository {
  _FakeDoseLogRepository({List<DoseLogEvent>? events})
    : _events = events ?? <DoseLogEvent>[];

  final List<DoseLogEvent> _events;
  final List<DoseLogEvent> addedEvents = <DoseLogEvent>[];
  int remainingAddFailures = 0;
  int addAttempts = 0;

  @override
  Future<void> addEvent(DoseLogEvent event) async {
    addAttempts += 1;
    if (remainingAddFailures > 0) {
      remainingAddFailures -= 1;
      throw StateError('dose log write failed');
    }
    addedEvents.add(event);
  }

  @override
  Stream<List<DoseLogEvent>> watchEvents() {
    return Stream.value(_events);
  }
}

ReminderSchedule _schedule({
  required String id,
  required int hour,
  required int minute,
  String? prescriptionId,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final timestamp = DateTime(2026, 7, 1);
  return ReminderSchedule(
    id: id,
    label: id,
    prescriptionId: prescriptionId,
    hour: hour,
    minute: minute,
    isEnabled: true,
    createdAt: createdAt ?? timestamp,
    updatedAt: updatedAt ?? timestamp,
  );
}

CarouselSlot _slot({
  required String id,
  required String scheduleId,
  required CarouselSlotStatus status,
}) {
  final timestamp = DateTime(2026, 7, 1);
  return CarouselSlot(
    id: id,
    slotNumber: id == 'slot-loaded' ? 1 : 2,
    prescriptionId: 'prescription-$id',
    scheduleId: scheduleId,
    profileId: ReminderSchedule.defaultProfileId,
    status: status,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
