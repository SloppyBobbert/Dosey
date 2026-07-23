import 'package:dosey_app/core/carousel/carousel_position.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';

enum GuidedCarouselLoadMode { fullReload, topOff }

enum GuidedCarouselLoadPlanSlotStatus { retained, loaded, shortage, empty }

enum GuidedCarouselLoadInvalidReason {
  interiorEmptyGap,
  nonLoadedRetainedPrefix,
  nonContiguousRetainedPrefix,
}

class CarouselDoseBundleMedication {
  const CarouselDoseBundleMedication({
    required this.prescriptionId,
    required this.prescriptionName,
    required this.scheduleId,
    required this.scheduledAt,
    required this.availableDoses,
    required this.guidedPillIcon,
    required this.doseCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String prescriptionId;
  final String prescriptionName;
  final String scheduleId;
  final DateTime scheduledAt;
  final int availableDoses;
  final GuidedPillIcon guidedPillIcon;
  final int doseCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class CarouselDoseBundle {
  CarouselDoseBundle({
    required this.bundleKey,
    required this.scheduledAt,
    required List<String> scheduleIds,
    required List<CarouselDoseBundleMedication> medications,
  }) : scheduleIds = List<String>.unmodifiable(scheduleIds),
       medications = List<CarouselDoseBundleMedication>.unmodifiable(
         medications,
       );

  final String bundleKey;
  final DateTime scheduledAt;
  final List<String> scheduleIds;
  final List<CarouselDoseBundleMedication> medications;
}

class CarouselLoadPlanShortage {
  CarouselLoadPlanShortage({
    required CarouselPosition position,
    required this.bundleKey,
    required this.scheduledAt,
    required List<String> scheduleIds,
  }) : position = _validateSlotPosition(position),
       scheduleIds = List<String>.unmodifiable(scheduleIds);

  final CarouselPosition position;
  final String bundleKey;
  final DateTime scheduledAt;
  final List<String> scheduleIds;

  int get slotNumber => position.value;
}

class CarouselLoadPlanSlotPreview {
  CarouselLoadPlanSlotPreview._({
    required CarouselPosition position,
    required this.status,
    this.bundle,
    this.shortage,
    List<String> scheduleIds = const <String>[],
    List<String> prescriptionIds = const <String>[],
    this.bundleKey,
  }) : position = _validateSlotPosition(position),
       scheduleIds = List<String>.unmodifiable(scheduleIds),
       prescriptionIds = List<String>.unmodifiable(prescriptionIds);

  factory CarouselLoadPlanSlotPreview.loaded({
    required CarouselPosition position,
    required CarouselDoseBundle bundle,
  }) {
    return CarouselLoadPlanSlotPreview._(
      position: position,
      status: GuidedCarouselLoadPlanSlotStatus.loaded,
      bundle: bundle,
      scheduleIds: bundle.scheduleIds,
      prescriptionIds: bundle.medications
          .map((medication) => medication.prescriptionId)
          .toList(growable: false),
      bundleKey: bundle.bundleKey,
    );
  }

  factory CarouselLoadPlanSlotPreview.retained({
    required CarouselPosition position,
    required List<String> scheduleIds,
    required List<String> prescriptionIds,
    String? bundleKey,
  }) {
    return CarouselLoadPlanSlotPreview._(
      position: position,
      status: GuidedCarouselLoadPlanSlotStatus.retained,
      scheduleIds: scheduleIds,
      prescriptionIds: prescriptionIds,
      bundleKey: bundleKey,
    );
  }

  factory CarouselLoadPlanSlotPreview.shortage({
    required CarouselPosition position,
    required CarouselLoadPlanShortage shortage,
  }) {
    return CarouselLoadPlanSlotPreview._(
      position: position,
      status: GuidedCarouselLoadPlanSlotStatus.shortage,
      shortage: shortage,
      scheduleIds: shortage.scheduleIds,
      bundleKey: shortage.bundleKey,
    );
  }

  factory CarouselLoadPlanSlotPreview.empty({
    required CarouselPosition position,
  }) {
    return CarouselLoadPlanSlotPreview._(
      position: position,
      status: GuidedCarouselLoadPlanSlotStatus.empty,
    );
  }

  final CarouselPosition position;
  final GuidedCarouselLoadPlanSlotStatus status;
  final CarouselDoseBundle? bundle;
  final CarouselLoadPlanShortage? shortage;
  final List<String> scheduleIds;
  final List<String> prescriptionIds;
  final String? bundleKey;

  int get slotNumber => position.value;
}

class GuidedCarouselLoadPlan {
  GuidedCarouselLoadPlan({
    required this.createdAt,
    required this.mode,
    this.priorPosition,
    required List<CarouselLoadPlanSlotPreview> slots,
    required List<CarouselLoadPlanShortage> shortages,
    this.invalidReason,
  }) : slots = List<CarouselLoadPlanSlotPreview>.unmodifiable(slots),
       shortages = List<CarouselLoadPlanShortage>.unmodifiable(shortages);

  final DateTime createdAt;
  final GuidedCarouselLoadMode mode;
  final CarouselPosition? priorPosition;
  final List<CarouselLoadPlanSlotPreview> slots;
  final List<CarouselLoadPlanShortage> shortages;
  final GuidedCarouselLoadInvalidReason? invalidReason;

  bool get isValid => invalidReason == null;
}

CarouselPosition _validateSlotPosition(CarouselPosition position) {
  if (!position.isDoseSlot) {
    throw ArgumentError.value(
      position.value,
      'position',
      'START/home cannot be used as a planned dose slot.',
    );
  }
  return position;
}
