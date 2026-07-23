import 'package:dosey_app/core/carousel/carousel_position.dart';
import 'package:dosey_app/core/carousel/guided_carousel_load_plan.dart';

enum CarouselLoadSessionStatus {
  draft,
  confirmed,
  stale,
  superseded,
  cancelled,
}

enum CarouselLoadSlotStatus {
  pending,
  loaded,
  retained,
  dispensed,
  skipped,
  empty,
  shortage,
  needsReview,
}

class CarouselLoadSession {
  CarouselLoadSession({
    required this.id,
    required this.mode,
    required this.status,
    this.predecessorSessionId,
    required this.startedAt,
    required this.updatedAt,
    CarouselPosition? currentPosition,
    required List<CarouselLoadSlotSnapshot> slots,
  }) : currentPosition = currentPosition ?? CarouselPosition.start,
       slots = List<CarouselLoadSlotSnapshot>.unmodifiable(slots);

  final String id;
  final GuidedCarouselLoadMode mode;
  final CarouselLoadSessionStatus status;
  final String? predecessorSessionId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final CarouselPosition currentPosition;
  final List<CarouselLoadSlotSnapshot> slots;
}

class CarouselLoadSlotSnapshot {
  CarouselLoadSlotSnapshot({
    required CarouselPosition position,
    required this.status,
    this.bundleKey,
    List<String> scheduleIds = const <String>[],
    List<String> prescriptionIds = const <String>[],
    this.scheduledAt,
    this.updatedAt,
  }) : position = _validateSlotPosition(position),
       scheduleIds = List<String>.unmodifiable(scheduleIds),
       prescriptionIds = List<String>.unmodifiable(prescriptionIds);

  final CarouselPosition position;
  final CarouselLoadSlotStatus status;
  final String? bundleKey;
  final List<String> scheduleIds;
  final List<String> prescriptionIds;
  final DateTime? scheduledAt;
  final DateTime? updatedAt;

  int get slotNumber => position.value;
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
