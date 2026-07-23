export 'package:dosey_app/core/carousel/guided_carousel_load_plan.dart';

import 'package:dosey_app/core/carousel/carousel_load_session.dart';
import 'package:dosey_app/core/carousel/carousel_position.dart';
import 'package:dosey_app/core/carousel/guided_carousel_load_plan.dart';

class GuidedCarouselLoadPlanner {
  static const int capacity = 14;

  GuidedCarouselLoadPlan buildFullReloadPlan({
    required List<CarouselDoseBundleMedication> medications,
    required DateTime now,
  }) {
    return _buildPlan(
      medications: medications,
      now: now,
      mode: GuidedCarouselLoadMode.fullReload,
      priorPosition: CarouselPosition.start,
      retainedPrefix: const <CarouselLoadPlanSlotPreview>[],
      firstFillSlot: 1,
    );
  }

  GuidedCarouselLoadPlan buildTopOffPlan({
    required CarouselLoadSession activeSession,
    required List<CarouselDoseBundleMedication> medications,
    required DateTime now,
  }) {
    final ordered = List<CarouselLoadSlotSnapshot>.from(activeSession.slots)
      ..sort((left, right) => left.slotNumber.compareTo(right.slotNumber));
    final retainedPrefix = <CarouselLoadPlanSlotPreview>[];
    var expectedSlotNumber = 1;
    var sawEmpty = false;
    var firstFillSlot = 1;

    for (final snapshot in ordered) {
      if (snapshot.slotNumber != expectedSlotNumber) {
        return _invalidTopOffPlan(
          now: now,
          priorPosition: activeSession.currentPosition,
          reason: GuidedCarouselLoadInvalidReason.nonContiguousRetainedPrefix,
        );
      }
      expectedSlotNumber += 1;

      if (snapshot.status == CarouselLoadSlotStatus.empty) {
        if (!sawEmpty) {
          sawEmpty = true;
          firstFillSlot = snapshot.slotNumber;
        }
        continue;
      }
      final isOccupiedPrefixSlot =
          snapshot.status == CarouselLoadSlotStatus.loaded ||
          snapshot.status == CarouselLoadSlotStatus.retained;
      if (!isOccupiedPrefixSlot) {
        return _invalidTopOffPlan(
          now: now,
          priorPosition: activeSession.currentPosition,
          reason: GuidedCarouselLoadInvalidReason.nonLoadedRetainedPrefix,
        );
      }
      if (sawEmpty) {
        return _invalidTopOffPlan(
          now: now,
          priorPosition: activeSession.currentPosition,
          reason: GuidedCarouselLoadInvalidReason.interiorEmptyGap,
        );
      }
      retainedPrefix.add(
        CarouselLoadPlanSlotPreview.retained(
          position: snapshot.position,
          scheduleIds: snapshot.scheduleIds,
          prescriptionIds: snapshot.prescriptionIds,
          bundleKey: snapshot.bundleKey,
        ),
      );
      firstFillSlot = snapshot.slotNumber + 1;
    }

    return _buildPlan(
      medications: medications,
      now: now,
      mode: GuidedCarouselLoadMode.topOff,
      priorPosition: activeSession.currentPosition,
      retainedPrefix: retainedPrefix,
      firstFillSlot: firstFillSlot,
    );
  }

  GuidedCarouselLoadPlan _invalidTopOffPlan({
    required DateTime now,
    required CarouselPosition priorPosition,
    required GuidedCarouselLoadInvalidReason reason,
  }) {
    return GuidedCarouselLoadPlan(
      createdAt: now,
      mode: GuidedCarouselLoadMode.topOff,
      priorPosition: priorPosition,
      slots: _emptyTailFrom(1),
      shortages: const [],
      invalidReason: reason,
    );
  }

  GuidedCarouselLoadPlan _buildPlan({
    required List<CarouselDoseBundleMedication> medications,
    required DateTime now,
    required GuidedCarouselLoadMode mode,
    required CarouselPosition priorPosition,
    required List<CarouselLoadPlanSlotPreview> retainedPrefix,
    required int firstFillSlot,
  }) {
    final bundlesByTime = _futureBundles(medications, now);
    final slots = <CarouselLoadPlanSlotPreview>[...retainedPrefix];
    final shortages = <CarouselLoadPlanShortage>[];
    final remainingDosesByPrescription = <String, int>{};
    var slotNumber = firstFillSlot;

    for (final entry in bundlesByTime.entries) {
      if (slotNumber > capacity) {
        break;
      }
      final bundle = _bundleFor(entry.key, entry.value);
      final remainingAfterBundle = <String, int>{};
      var hasShortage = false;

      for (final medication in bundle.medications) {
        final remainingDoses = remainingAfterBundle.putIfAbsent(
          medication.prescriptionId,
          () => remainingDosesByPrescription.putIfAbsent(
            medication.prescriptionId,
            () => medication.availableDoses,
          ),
        );
        if (remainingDoses < 1) {
          hasShortage = true;
          break;
        }
        remainingAfterBundle[medication.prescriptionId] = remainingDoses - 1;
      }

      if (hasShortage) {
        final shortage = CarouselLoadPlanShortage(
          position: CarouselPosition(slotNumber),
          bundleKey: bundle.bundleKey,
          scheduledAt: bundle.scheduledAt,
          scheduleIds: bundle.scheduleIds,
        );
        shortages.add(shortage);
        slots.add(
          CarouselLoadPlanSlotPreview.shortage(
            position: CarouselPosition(slotNumber),
            shortage: shortage,
          ),
        );
        slots.addAll(_emptyTailFrom(slotNumber + 1));
        return GuidedCarouselLoadPlan(
          createdAt: now,
          mode: mode,
          priorPosition: priorPosition,
          slots: slots,
          shortages: shortages,
        );
      }

      remainingDosesByPrescription.addAll(remainingAfterBundle);
      slots.add(
        CarouselLoadPlanSlotPreview.loaded(
          position: CarouselPosition(slotNumber),
          bundle: bundle,
        ),
      );
      slotNumber += 1;
    }

    slots.addAll(_emptyTailFrom(slotNumber));
    return GuidedCarouselLoadPlan(
      createdAt: now,
      mode: mode,
      priorPosition: priorPosition,
      slots: slots,
      shortages: shortages,
    );
  }

  Map<DateTime, List<CarouselDoseBundleMedication>> _futureBundles(
    List<CarouselDoseBundleMedication> medications,
    DateTime now,
  ) {
    final sortedMedications =
        List<CarouselDoseBundleMedication>.from(medications)
          ..retainWhere((medication) => medication.scheduledAt.isAfter(now))
          ..sort((left, right) {
            final scheduledComparison = left.scheduledAt.compareTo(
              right.scheduledAt,
            );
            if (scheduledComparison != 0) {
              return scheduledComparison;
            }
            return left.scheduleId.compareTo(right.scheduleId);
          });

    final bundlesByTime = <DateTime, List<CarouselDoseBundleMedication>>{};
    for (final medication in sortedMedications) {
      bundlesByTime
          .putIfAbsent(
            medication.scheduledAt,
            () => <CarouselDoseBundleMedication>[],
          )
          .add(medication);
    }
    return bundlesByTime;
  }

  CarouselDoseBundle _bundleFor(
    DateTime scheduledAt,
    List<CarouselDoseBundleMedication> medications,
  ) {
    final bundleMedications = List<CarouselDoseBundleMedication>.from(
      medications,
    )..sort((left, right) => left.scheduleId.compareTo(right.scheduleId));
    final scheduleIds = bundleMedications
        .map((medication) => medication.scheduleId)
        .toList(growable: false);
    return CarouselDoseBundle(
      bundleKey: _bundleKey(scheduledAt, scheduleIds),
      scheduledAt: scheduledAt,
      scheduleIds: scheduleIds,
      medications: bundleMedications,
    );
  }

  List<CarouselLoadPlanSlotPreview> _emptyTailFrom(int startingSlot) {
    final slots = <CarouselLoadPlanSlotPreview>[];
    for (var slot = startingSlot; slot <= capacity; slot += 1) {
      slots.add(
        CarouselLoadPlanSlotPreview.empty(position: CarouselPosition(slot)),
      );
    }
    return slots;
  }

  String _bundleKey(DateTime scheduledAt, List<String> scheduleIds) {
    final sortedScheduleIds = List<String>.from(scheduleIds)..sort();
    return '${scheduledAt.toUtc().toIso8601String()}|${sortedScheduleIds.join(',')}';
  }
}
