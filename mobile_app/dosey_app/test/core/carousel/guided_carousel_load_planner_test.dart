import 'package:dosey_app/core/carousel/carousel_load_session.dart';
import 'package:dosey_app/core/carousel/carousel_position.dart';
import 'package:dosey_app/core/carousel/guided_carousel_load_planner.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CarouselPosition', () {
    test('accepts 0 and 14, rejects -1 and 15', () {
      expect(CarouselPosition(0).value, 0);
      expect(CarouselPosition(14).value, 14);
      expect(() => CarouselPosition(-1), throwsArgumentError);
      expect(() => CarouselPosition(15), throwsArgumentError);
    });

    test('counterclockwise progression wraps through 0,1,...,14,0', () {
      final values = <int>[0];
      var current = CarouselPosition.start;
      for (var i = 0; i < 15; i += 1) {
        current = current.nextCounterclockwise();
        values.add(current.value);
      }

      expect(values, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 0]);
    });
  });

  group('GuidedCarouselLoadPlanner', () {
    final planner = GuidedCarouselLoadPlanner();
    final now = DateTime.utc(2026, 7, 22, 8);

    test('same-time medications group into one bundle', () {
      final plan = planner.buildFullReloadPlan(
        medications: [
          _medication(
            prescriptionId: 'med-a',
            scheduleId: 'schedule-a',
            scheduledAt: DateTime.utc(2026, 7, 22, 9),
          ),
          _medication(
            prescriptionId: 'med-b',
            scheduleId: 'schedule-b',
            scheduledAt: DateTime.utc(2026, 7, 22, 9),
          ),
        ],
        now: now,
      );

      expect(plan.mode, GuidedCarouselLoadMode.fullReload);
      expect(plan.slots.first.position.value, 1);
      expect(plan.slots.first.bundle!.medications, hasLength(2));
      expect(plan.slots[1].status, GuidedCarouselLoadPlanSlotStatus.empty);
    });

    test('future-only planning excludes past and overdue occurrences', () {
      final plan = planner.buildFullReloadPlan(
        medications: [
          _medication(
            prescriptionId: 'past-med',
            scheduleId: 'past-schedule',
            scheduledAt: DateTime.utc(2026, 7, 22, 7, 59),
          ),
          _medication(
            prescriptionId: 'now-med',
            scheduleId: 'now-schedule',
            scheduledAt: DateTime.utc(2026, 7, 22, 8),
          ),
          _medication(
            prescriptionId: 'future-med',
            scheduleId: 'future-schedule',
            scheduledAt: DateTime.utc(2026, 7, 22, 8, 1),
          ),
        ],
        now: now,
      );

      expect(plan.slots.first.bundle!.scheduleIds, ['future-schedule']);
      expect(
        plan.slots.where(
          (slot) => slot.status == GuidedCarouselLoadPlanSlotStatus.loaded,
        ),
        hasLength(1),
      );
    });

    test(
      'full-load planning fills slots 1..14 only and never creates slot 0 or 15',
      () {
        final plan = planner.buildFullReloadPlan(
          medications: List<CarouselDoseBundleMedication>.generate(
            14,
            (index) => _medication(
              prescriptionId: 'med-$index',
              scheduleId: 'schedule-$index',
              scheduledAt: DateTime.utc(2026, 7, 22, 9 + index),
            ),
          ),
          now: now,
        );

        expect(plan.slots, hasLength(14));
        expect(plan.slots.first.position.value, 1);
        expect(plan.slots.last.position.value, 14);
        expect(plan.slots.any((slot) => slot.position.value == 0), isFalse);
        expect(plan.slots.any((slot) => slot.position.value == 15), isFalse);
      },
    );

    test(
      'shortage stops at first insufficient future occurrence and later slots stay empty',
      () {
        final plan = planner.buildFullReloadPlan(
          medications: [
            _medication(
              prescriptionId: 'med-1',
              scheduleId: 'schedule-1',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
            ),
            _medication(
              prescriptionId: 'med-2',
              scheduleId: 'schedule-2',
              scheduledAt: DateTime.utc(2026, 7, 22, 10),
              availableDoses: 0,
            ),
            _medication(
              prescriptionId: 'med-3',
              scheduleId: 'schedule-3',
              scheduledAt: DateTime.utc(2026, 7, 22, 11),
            ),
          ],
          now: now,
        );

        expect(plan.slots[0].status, GuidedCarouselLoadPlanSlotStatus.loaded);
        expect(plan.slots[1].status, GuidedCarouselLoadPlanSlotStatus.shortage);
        expect(plan.slots[1].shortage!.position.value, 2);
        expect(plan.slots[2].status, GuidedCarouselLoadPlanSlotStatus.empty);
        expect(plan.shortages, hasLength(1));
      },
    );

    test(
      'repeated use of the same prescription consumes inventory cumulatively across bundles and within same-time rows',
      () {
        final acrossBundles = planner.buildFullReloadPlan(
          medications: [
            _medication(
              prescriptionId: 'shared-med',
              scheduleId: 'schedule-1',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
              availableDoses: 1,
            ),
            _medication(
              prescriptionId: 'shared-med',
              scheduleId: 'schedule-2',
              scheduledAt: DateTime.utc(2026, 7, 22, 10),
              availableDoses: 1,
            ),
          ],
          now: now,
        );
        final withinBundle = planner.buildFullReloadPlan(
          medications: [
            _medication(
              prescriptionId: 'shared-med',
              scheduleId: 'schedule-3',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
              availableDoses: 1,
            ),
            _medication(
              prescriptionId: 'shared-med',
              scheduleId: 'schedule-4',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
              availableDoses: 1,
            ),
          ],
          now: now,
        );

        expect(
          acrossBundles.slots[0].status,
          GuidedCarouselLoadPlanSlotStatus.loaded,
        );
        expect(
          acrossBundles.slots[1].status,
          GuidedCarouselLoadPlanSlotStatus.shortage,
        );
        expect(
          withinBundle.slots[0].status,
          GuidedCarouselLoadPlanSlotStatus.shortage,
        );
      },
    );

    test('doseCount does not consume extra inventory for one occurrence', () {
      final plan = planner.buildFullReloadPlan(
        medications: [
          _medication(
            prescriptionId: 'shared-med',
            scheduleId: 'schedule-1',
            scheduledAt: DateTime.utc(2026, 7, 22, 9),
            availableDoses: 1,
            doseCount: 2,
          ),
          _medication(
            prescriptionId: 'shared-med',
            scheduleId: 'schedule-2',
            scheduledAt: DateTime.utc(2026, 7, 22, 10),
            availableDoses: 1,
            doseCount: 2,
          ),
        ],
        now: now,
      );

      expect(plan.slots[0].status, GuidedCarouselLoadPlanSlotStatus.loaded);
      expect(plan.slots[1].status, GuidedCarouselLoadPlanSlotStatus.shortage);
    });

    test(
      'top-off keeps retained loaded prefix and fills only the contiguous empty tail',
      () {
        final session = CarouselLoadSession(
          id: 'session-1',
          mode: GuidedCarouselLoadMode.topOff,
          status: CarouselLoadSessionStatus.confirmed,
          startedAt: now,
          updatedAt: now,
          currentPosition: CarouselPosition(5),
          slots: [
            _snapshot(
              1,
              CarouselLoadSlotStatus.loaded,
              scheduleIds: ['kept-1'],
            ),
            _snapshot(
              2,
              CarouselLoadSlotStatus.loaded,
              scheduleIds: ['kept-2'],
            ),
            _snapshot(3, CarouselLoadSlotStatus.empty),
            _snapshot(4, CarouselLoadSlotStatus.empty),
          ],
        );

        final plan = planner.buildTopOffPlan(
          activeSession: session,
          medications: [
            _medication(
              prescriptionId: 'new-med-a',
              scheduleId: 'new-schedule-a',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
            ),
            _medication(
              prescriptionId: 'new-med-b',
              scheduleId: 'new-schedule-b',
              scheduledAt: DateTime.utc(2026, 7, 22, 10),
            ),
          ],
          now: now,
        );

        expect(plan.mode, GuidedCarouselLoadMode.topOff);
        expect(plan.isValid, isTrue);
        expect(plan.priorPosition, CarouselPosition(5));
        expect(plan.slots[0].status, GuidedCarouselLoadPlanSlotStatus.retained);
        expect(plan.slots[0].scheduleIds, ['kept-1']);
        expect(plan.slots[1].status, GuidedCarouselLoadPlanSlotStatus.retained);
        expect(plan.slots[2].status, GuidedCarouselLoadPlanSlotStatus.loaded);
        expect(plan.slots[3].status, GuidedCarouselLoadPlanSlotStatus.loaded);
        expect(plan.slots[4].status, GuidedCarouselLoadPlanSlotStatus.empty);
      },
    );

    test(
      'top-off rejects interior empty gaps with an explicit invalid reason',
      () {
        final session = CarouselLoadSession(
          id: 'session-gap',
          mode: GuidedCarouselLoadMode.topOff,
          status: CarouselLoadSessionStatus.confirmed,
          startedAt: now,
          updatedAt: now,
          currentPosition: CarouselPosition(4),
          slots: [
            _snapshot(1, CarouselLoadSlotStatus.loaded),
            _snapshot(2, CarouselLoadSlotStatus.empty),
            _snapshot(3, CarouselLoadSlotStatus.loaded),
          ],
        );

        final plan = planner.buildTopOffPlan(
          activeSession: session,
          medications: [
            _medication(
              prescriptionId: 'new-med',
              scheduleId: 'new-schedule',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
            ),
          ],
          now: now,
        );

        expect(plan.isValid, isFalse);
        expect(
          plan.invalidReason,
          GuidedCarouselLoadInvalidReason.interiorEmptyGap,
        );
      },
    );

    test(
      'top-off rejects retained non-loaded statuses with an explicit invalid reason',
      () {
        final session = CarouselLoadSession(
          id: 'session-shortage',
          mode: GuidedCarouselLoadMode.topOff,
          status: CarouselLoadSessionStatus.confirmed,
          startedAt: now,
          updatedAt: now,
          currentPosition: CarouselPosition(2),
          slots: [
            _snapshot(1, CarouselLoadSlotStatus.shortage),
            _snapshot(2, CarouselLoadSlotStatus.empty),
          ],
        );

        final plan = planner.buildTopOffPlan(
          activeSession: session,
          medications: [
            _medication(
              prescriptionId: 'new-med',
              scheduleId: 'new-schedule',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
            ),
          ],
          now: now,
        );

        expect(plan.isValid, isFalse);
        expect(
          plan.invalidReason,
          GuidedCarouselLoadInvalidReason.nonLoadedRetainedPrefix,
        );
      },
    );

    test(
      'top-off rejects sparse non-contiguous prefix input with an explicit invalid reason',
      () {
        final session = CarouselLoadSession(
          id: 'session-sparse',
          mode: GuidedCarouselLoadMode.topOff,
          status: CarouselLoadSessionStatus.confirmed,
          startedAt: now,
          updatedAt: now,
          currentPosition: CarouselPosition(4),
          slots: [
            _snapshot(2, CarouselLoadSlotStatus.loaded),
            _snapshot(3, CarouselLoadSlotStatus.empty),
          ],
        );

        final plan = planner.buildTopOffPlan(
          activeSession: session,
          medications: [
            _medication(
              prescriptionId: 'new-med',
              scheduleId: 'new-schedule',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
            ),
          ],
          now: now,
        );

        expect(plan.isValid, isFalse);
        expect(
          plan.invalidReason,
          GuidedCarouselLoadInvalidReason.nonContiguousRetainedPrefix,
        );
      },
    );

    test(
      'top-off respects slot numbering and does not reorder retained loaded doses',
      () {
        final session = CarouselLoadSession(
          id: 'session-order',
          mode: GuidedCarouselLoadMode.topOff,
          status: CarouselLoadSessionStatus.confirmed,
          startedAt: now,
          updatedAt: now,
          currentPosition: CarouselPosition(3),
          slots: [
            _snapshot(1, CarouselLoadSlotStatus.loaded, scheduleIds: ['first']),
            _snapshot(
              2,
              CarouselLoadSlotStatus.loaded,
              scheduleIds: ['second'],
            ),
            _snapshot(3, CarouselLoadSlotStatus.empty),
          ],
        );

        final plan = planner.buildTopOffPlan(
          activeSession: session,
          medications: [
            _medication(
              prescriptionId: 'new-med',
              scheduleId: 'third',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
            ),
          ],
          now: now,
        );

        expect(plan.slots.take(3).map((slot) => slot.position.value), [
          1,
          2,
          3,
        ]);
        expect(plan.slots[0].scheduleIds, ['first']);
        expect(plan.slots[1].scheduleIds, ['second']);
        expect(plan.slots[2].bundle!.scheduleIds, ['third']);
      },
    );

    test(
      'top-off over a persisted 14-slot session starts filling at the first empty tail slot',
      () {
        final session = CarouselLoadSession(
          id: 'session-persisted-tail',
          mode: GuidedCarouselLoadMode.topOff,
          status: CarouselLoadSessionStatus.confirmed,
          startedAt: now,
          updatedAt: now,
          currentPosition: CarouselPosition(8),
          slots: [
            _snapshot(
              1,
              CarouselLoadSlotStatus.loaded,
              scheduleIds: ['kept-1'],
            ),
            _snapshot(
              2,
              CarouselLoadSlotStatus.loaded,
              scheduleIds: ['kept-2'],
            ),
            ...List<CarouselLoadSlotSnapshot>.generate(
              12,
              (index) => _snapshot(index + 3, CarouselLoadSlotStatus.empty),
            ),
          ],
        );

        final plan = planner.buildTopOffPlan(
          activeSession: session,
          medications: [
            _medication(
              prescriptionId: 'new-med-a',
              scheduleId: 'schedule-3',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
            ),
            _medication(
              prescriptionId: 'new-med-b',
              scheduleId: 'schedule-4',
              scheduledAt: DateTime.utc(2026, 7, 22, 10),
            ),
          ],
          now: now,
        );

        expect(plan.isValid, isTrue);
        expect(plan.slots, hasLength(14));
        expect(plan.slots[0].status, GuidedCarouselLoadPlanSlotStatus.retained);
        expect(plan.slots[1].status, GuidedCarouselLoadPlanSlotStatus.retained);
        expect(plan.slots[2].status, GuidedCarouselLoadPlanSlotStatus.loaded);
        expect(plan.slots[2].position.value, 3);
        expect(plan.slots[3].status, GuidedCarouselLoadPlanSlotStatus.loaded);
        expect(plan.slots[3].position.value, 4);
        expect(plan.slots.last.status, GuidedCarouselLoadPlanSlotStatus.empty);
      },
    );

    test(
      'top-off accepts retained prefix slots after repository round-trip and replans from them',
      () {
        final session = CarouselLoadSession(
          id: 'session-retained-replan',
          mode: GuidedCarouselLoadMode.topOff,
          status: CarouselLoadSessionStatus.confirmed,
          startedAt: now,
          updatedAt: now,
          currentPosition: CarouselPosition(6),
          slots: [
            _snapshot(
              1,
              CarouselLoadSlotStatus.retained,
              scheduleIds: ['kept-1'],
              prescriptionIds: ['med-1'],
            ),
            _snapshot(
              2,
              CarouselLoadSlotStatus.retained,
              scheduleIds: ['kept-2'],
              prescriptionIds: ['med-2'],
            ),
            ...List<CarouselLoadSlotSnapshot>.generate(
              12,
              (index) => _snapshot(index + 3, CarouselLoadSlotStatus.empty),
            ),
          ],
        );

        final plan = planner.buildTopOffPlan(
          activeSession: session,
          medications: [
            _medication(
              prescriptionId: 'new-med',
              scheduleId: 'schedule-3',
              scheduledAt: DateTime.utc(2026, 7, 22, 9),
            ),
          ],
          now: now,
        );

        expect(plan.isValid, isTrue);
        expect(plan.slots[0].status, GuidedCarouselLoadPlanSlotStatus.retained);
        expect(plan.slots[1].status, GuidedCarouselLoadPlanSlotStatus.retained);
        expect(plan.slots[2].status, GuidedCarouselLoadPlanSlotStatus.loaded);
        expect(plan.slots[2].position.value, 3);
      },
    );

    test(
      'plan and session preserve current position metadata for later top-off return flow',
      () {
        final sourceSlots = <CarouselLoadPlanSlotPreview>[
          CarouselLoadPlanSlotPreview.retained(
            position: CarouselPosition(1),
            scheduleIds: const ['schedule-a'],
            prescriptionIds: const ['med-a'],
            bundleKey: 'bundle-a',
          ),
        ];
        final sourceSnapshots = <CarouselLoadSlotSnapshot>[
          CarouselLoadSlotSnapshot(
            position: CarouselPosition(1),
            status: CarouselLoadSlotStatus.loaded,
            scheduleIds: const ['schedule-a'],
          ),
        ];

        final plan = GuidedCarouselLoadPlan(
          createdAt: now,
          mode: GuidedCarouselLoadMode.topOff,
          priorPosition: CarouselPosition(7),
          slots: sourceSlots,
          shortages: const [],
        );
        final session = CarouselLoadSession(
          id: 'session-meta',
          mode: GuidedCarouselLoadMode.topOff,
          status: CarouselLoadSessionStatus.confirmed,
          startedAt: now,
          updatedAt: now,
          currentPosition: CarouselPosition(7),
          slots: sourceSnapshots,
        );

        sourceSlots.add(
          CarouselLoadPlanSlotPreview.empty(position: CarouselPosition(2)),
        );
        sourceSnapshots.add(
          CarouselLoadSlotSnapshot(
            position: CarouselPosition(2),
            status: CarouselLoadSlotStatus.empty,
          ),
        );

        expect(plan.priorPosition, CarouselPosition(7));
        expect(plan.slots, hasLength(1));
        expect(session.currentPosition, CarouselPosition(7));
        expect(session.slots, hasLength(1));
      },
    );
  });
}

CarouselLoadSlotSnapshot _snapshot(
  int slot,
  CarouselLoadSlotStatus status, {
  List<String> scheduleIds = const <String>[],
  List<String> prescriptionIds = const <String>[],
  String? bundleKey,
}) {
  return CarouselLoadSlotSnapshot(
    position: CarouselPosition(slot),
    status: status,
    scheduleIds: scheduleIds,
    prescriptionIds: prescriptionIds,
    bundleKey: bundleKey,
  );
}

CarouselDoseBundleMedication _medication({
  required String prescriptionId,
  required String scheduleId,
  required DateTime scheduledAt,
  int availableDoses = 1,
  int doseCount = 1,
}) {
  final now = DateTime.utc(2026, 7, 22, 8);
  return CarouselDoseBundleMedication(
    prescriptionId: prescriptionId,
    prescriptionName: prescriptionId,
    scheduleId: scheduleId,
    scheduledAt: scheduledAt,
    availableDoses: availableDoses,
    guidedPillIcon: GuidedPillIcon.roundPill,
    doseCount: doseCount,
    createdAt: now,
    updatedAt: now,
  );
}
